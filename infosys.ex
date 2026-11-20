defmodule WMX.Orchestrator do
  @moduledoc """
  BEAM orchestration module for The Web Machine X.
  Tracks polyglot pipeline tasks, node telemetry, bounded logs, health scores,
  JSON snapshots, and direct calls into `:wmx_engine`.
  """

  use GenServer

  @default_max_logs 256
  @default_max_tasks 128
  @default_max_samples 64

  @supported_languages [
    :elm,
    :erlang,
    :elixir,
    :cobol,
    :fortran,
    :assembly,
    :ruby,
    :sql,
    :pascal,
    :rust,
    :javascript,
    :python,
    :csharp,
    :haskell,
    :json,
    :c,
    :cpp,
    :scss,
    :typescript
  ]

  defstruct started_at: 0,
            seq: 0,
            nodes: %{},
            metrics: %{},
            tasks: [],
            logs: [],
            max_logs: @default_max_logs,
            max_tasks: @default_max_tasks,
            max_samples: @default_max_samples

  ## ===================================================================
  ## Client API
  ## ===================================================================

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def stop(server \\ __MODULE__) do
    GenServer.stop(server, :normal)
  end

  def ping(server \\ __MODULE__) do
    GenServer.call(server, :ping)
  end

  def snapshot(server \\ __MODULE__) do
    GenServer.call(server, :snapshot)
  end

  def register_node(server \\ __MODULE__, id, attrs \\ %{}) do
    GenServer.call(server, {:register_node, id, normalize_map(attrs)})
  end

  def unregister_node(server \\ __MODULE__, id) do
    GenServer.call(server, {:unregister_node, id})
  end

  def set_node_status(server \\ __MODULE__, id, status) do
    GenServer.call(server, {:set_node_status, id, status})
  end

  def list_nodes(server \\ __MODULE__) do
    GenServer.call(server, :list_nodes)
  end

  def get_node(server \\ __MODULE__, id) do
    GenServer.call(server, {:get_node, id})
  end

  def record_metric(server \\ __MODULE__, node_id, key, value) when is_number(value) do
    GenServer.call(server, {:record_metric, node_id, key, value * 1.0})
  end

  def get_metrics(server \\ __MODULE__, node_id) do
    GenServer.call(server, {:get_metrics, node_id})
  end

  def clear_metrics(server \\ __MODULE__) do
    GenServer.call(server, :clear_metrics)
  end

  def record_task(server \\ __MODULE__, component, duration_ms, status \\ :ok, opts \\ %{})
      when is_integer(duration_ms) and duration_ms >= 0 do
    GenServer.call(server, {:record_task, component, duration_ms, status, normalize_map(opts)})
  end

  def list_tasks(server \\ __MODULE__) do
    GenServer.call(server, :list_tasks)
  end

  def task_summary(server \\ __MODULE__) do
    GenServer.call(server, :task_summary)
  end

  def append_log(server \\ __MODULE__, level, message) do
    GenServer.call(server, {:append_log, normalize_level(level), to_string(message)})
  end

  def recent_logs(server \\ __MODULE__, limit \\ 20) when is_integer(limit) and limit >= 0 do
    GenServer.call(server, {:recent_logs, limit})
  end

  def evaluate_health(server \\ __MODULE__) do
    GenServer.call(server, :evaluate_health)
  end

  def compute_score(server \\ __MODULE__) do
    GenServer.call(server, :compute_score)
  end

  def status_line(server \\ __MODULE__) do
    GenServer.call(server, :status_line)
  end

  def to_json(server \\ __MODULE__) do
    GenServer.call(server, :to_json)
  end

  def reset_counters(server \\ __MODULE__) do
    GenServer.call(server, :reset_counters)
  end

  def sync_with_erlang(server \\ __MODULE__, erl_pid) when is_pid(erl_pid) do
    GenServer.call(server, {:sync_with_erlang, erl_pid})
  end

  ## ===================================================================
  ## GenServer Callbacks
  ## ===================================================================

  @impl true
  def init(opts) do
    now = now_ms()

    state = %__MODULE__{
      started_at: now,
      seq: 1,
      nodes: default_nodes(now),
      metrics: %{},
      tasks: [],
      logs: [
        %{
          seq: 1,
          level: :info,
          message: "WMX.Orchestrator initialized",
          timestamp: now
        }
      ],
      max_logs: Keyword.get(opts, :max_logs, @default_max_logs),
      max_tasks: Keyword.get(opts, :max_tasks, @default_max_tasks),
      max_samples: Keyword.get(opts, :max_samples, @default_max_samples)
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    {:reply, {:pong, now_ms()}, state}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:register_node, id, attrs}, _from, state) do
    now = now_ms()
    existing = Map.get(state.nodes, id)

    restarts =
      case existing do
        %{restarts: r} -> r + 1
        nil -> 0
      end

    node = %{
      id: id,
      kind: Map.get(attrs, :kind, :worker),
      endpoint: Map.get(attrs, :endpoint, "beam://local"),
      status: normalize_status(Map.get(attrs, :status, :online)),
      latency_ms: Map.get(attrs, :latency_ms, 3),
      load_pct: clamp_pct(Map.get(attrs, :load_pct, 0.0)),
      restarts: restarts,
      last_seen: now,
      tags: Map.get(attrs, :tags, [])
    }

    nodes = Map.put(state.nodes, id, node)
    next_state = push_log(%{state | nodes: nodes}, :info, "registered node #{inspect(id)}")
    {:reply, {:ok, node}, next_state}
  end

  @impl true
  def handle_call({:unregister_node, id}, _from, state) do
    if Map.has_key?(state.nodes, id) do
      nodes = Map.delete(state.nodes, id)
      next_state = push_log(%{state | nodes: nodes}, :warn, "unregistered node #{inspect(id)}")
      {:reply, :ok, next_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:set_node_status, id, status}, _from, state) do
    norm_status = normalize_status(status)

    case Map.fetch(state.nodes, id) do
      {:ok, node} ->
        updated = %{node | status: norm_status, last_seen: now_ms()}
        nodes = Map.put(state.nodes, id, updated)

        next_state =
          push_log(
            %{state | nodes: nodes},
            :info,
            "node #{inspect(id)} status -> #{norm_status}"
          )

        {:reply, {:ok, updated}, next_state}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_nodes, _from, state) do
    {:reply, {:ok, Map.values(state.nodes)}, state}
  end

  @impl true
  def handle_call({:get_node, id}, _from, state) do
    case Map.fetch(state.nodes, id) do
      {:ok, node} -> {:reply, {:ok, node}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:record_metric, node_id, key, value}, _from, state) do
    now = now_ms()
    node_series_map = Map.get(state.metrics, node_id, %{})
    series = Map.get(node_series_map, key, [])
    updated_series = bounded_prepend({now, value}, series, state.max_samples)
    updated_node_map = Map.put(node_series_map, key, updated_series)
    updated_metrics = Map.put(state.metrics, node_id, updated_node_map)
    updated_nodes = apply_node_metric_hint(state.nodes, node_id, key, value, now)

    {:reply, :ok, %{state | metrics: updated_metrics, nodes: updated_nodes}}
  end

  @impl true
  def handle_call({:get_metrics, node_id}, _from, state) do
    {:reply, {:ok, Map.get(state.metrics, node_id, %{})}, state}
  end

  @impl true
  def handle_call(:clear_metrics, _from, state) do
    next_state = push_log(%{state | metrics: %{}}, :info, "cleared metrics buffer")
    {:reply, :ok, next_state}
  end

  @impl true
  def handle_call({:record_task, component, duration_ms, status, opts}, _from, state) do
    now = now_ms()
    next_seq = state.seq + 1
    lang = Map.get(opts, :lang, infer_lang_from_component(component))
    lines = Map.get(opts, :lines, infer_lines(lang))

    entry = %{
      id: next_seq,
      component: to_string(component),
      lang: lang,
      duration_ms: duration_ms,
      status: status,
      lines: lines,
      timestamp: now
    }

    tasks = bounded_prepend(entry, state.tasks, state.max_tasks)
    log_level = if status in [:ok, :success], do: :info, else: :error
    msg = "task ##{next_seq} [#{entry.component}] #{status} in #{duration_ms}ms"

    next_state =
      push_log(%{state | seq: next_seq, tasks: tasks}, log_level, msg)

    {:reply, {:ok, entry}, next_state}
  end

  @impl true
  def handle_call(:list_tasks, _from, state) do
    {:reply, {:ok, state.tasks}, state}
  end

  @impl true
  def handle_call(:task_summary, _from, state) do
    {:reply, {:ok, summarize_tasks(state.tasks)}, state}
  end

  @impl true
  def handle_call({:append_log, level, message}, _from, state) do
    {:reply, :ok, push_log(state, level, message)}
  end

  @impl true
  def handle_call({:recent_logs, limit}, _from, state) do
    {:reply, {:ok, Enum.take(state.logs, limit)}, state}
  end

  @impl true
  def handle_call(:evaluate_health, _from, state) do
    {:reply, {:ok, calc_health(state)}, state}
  end

  @impl true
  def handle_call(:compute_score, _from, state) do
    {:reply, {:ok, calc_score(state)}, state}
  end

  @impl true
  def handle_call(:status_line, _from, state) do
    {:reply, {:ok, format_status_line(state)}, state}
  end

  @impl true
  def handle_call(:to_json, _from, state) do
    {:reply, {:ok, render_json_snapshot(state)}, state}
  end

  @impl true
  def handle_call(:reset_counters, _from, state) do
    now = now_ms()

    reset_state = %{
      state
      | started_at: now,
        seq: 1,
        tasks: [],
        metrics: %{},
        logs: [%{seq: 1, level: :info, message: "counters reset", timestamp: now}]
    }

    {:reply, :ok, reset_state}
  end

  @impl true
  def handle_call({:sync_with_erlang, erl_pid}, _from, state) do
    result =
      try do
        line = :wmx_engine.format_status_line(erl_pid)
        {:ok, line}
      catch
        kind, reason -> {:error, {kind, reason}}
      end

    next_state =
      case result do
        {:ok, erl_line} ->
          push_log(state, :info, "synced with :wmx_engine -> #{erl_line}")

        {:error, err} ->
          push_log(state, :warn, "erlang sync failed: #{inspect(err)}")
      end

    {:reply, result, next_state}
  end

  ## ===================================================================
  ## State Helpers & Telemetry Logic
  ## ===================================================================

  defp default_nodes(now) do
    %{
      elm_ui: %{
        id: :elm_ui,
        kind: :frontend,
        endpoint: "browser://web-machine-x.js",
        status: :online,
        latency_ms: 2,
        load_pct: 10.5,
        restarts: 0,
        last_seen: now,
        tags: [:elm, :html, :css]
      },
      erlang_core: %{
        id: :erlang_core,
        kind: :runtime,
        endpoint: "beam://wmx_engine",
        status: :online,
        latency_ms: 3,
        load_pct: 14.0,
        restarts: 0,
        last_seen: now,
        tags: [:erlang, :beam]
      },
      elixir_orch: %{
        id: :elixir_orch,
        kind: :coordinator,
        endpoint: "beam://wmx_orchestrator",
        status: :online,
        latency_ms: 2,
        load_pct: 11.2,
        restarts: 0,
        last_seen: now,
        tags: [:elixir, :genserver]
      }
    }
  end

  defp push_log(state, level, message) do
    next_seq = state.seq + 1

    entry = %{
      seq: next_seq,
      level: normalize_level(level),
      message: to_string(message),
      timestamp: now_ms()
    }

    logs = bounded_prepend(entry, state.logs, state.max_logs)
    %{state | seq: next_seq, logs: logs}
  end

  defp bounded_prepend(item, list, max_len) when is_integer(max_len) and max_len > 0 do
    trimmed =
      if length(list) >= max_len do
        Enum.take(list, max_len - 1)
      else
        list
      end

    [item | trimmed]
  end

  defp bounded_prepend(_item, _list, _max_len), do: []

  defp apply_node_metric_hint(nodes, node_id, :latency_ms, value, now) do
    case Map.fetch(nodes, node_id) do
      {:ok, node} ->
        Map.put(nodes, node_id, %{node | latency_ms: round(value), last_seen: now})

      :error ->
        nodes
    end
  end

  defp apply_node_metric_hint(nodes, node_id, :load_pct, value, now) do
    case Map.fetch(nodes, node_id) do
      {:ok, node} ->
        Map.put(nodes, node_id, %{node | load_pct: clamp_pct(value), last_seen: now})

      :error ->
        nodes
    end
  end

  defp apply_node_metric_hint(nodes, node_id, _key, _value, now) do
    case Map.fetch(nodes, node_id) do
      {:ok, node} ->
        Map.put(nodes, node_id, %{node | last_seen: now})

      :error ->
        nodes
    end
  end

  defp summarize_tasks(tasks) do
    total = length(tasks)
    succeeded = Enum.count(tasks, fn t -> t.status in [:ok, :success] end)
    failed = total - succeeded

    total_ms =
      tasks
      |> Enum.map(& &1.duration_ms)
      |> Enum.sum()

    avg_ms =
      if total == 0 do
        0.0
      else
        round_2(total_ms / total)
      end

    total_lines =
      tasks
      |> Enum.map(& &1.lines)
      |> Enum.sum()

    %{
      total: total,
      succeeded: succeeded,
      failed: failed,
      avg_duration_ms: avg_ms,
      total_lines: total_lines
    }
  end

  defp calc_health(state) do
    nodes = Map.values(state.nodes)
    total = length(nodes)
    online = Enum.count(nodes, fn n -> n.status == :online end)

    avg_load =
      if total == 0 do
        0.0
      else
        loads = Enum.map(nodes, & &1.load_pct)
        round_2(Enum.sum(loads) / total)
      end

    max_latency =
      case nodes do
        [] -> 0
        _ -> nodes |> Enum.map(& &1.latency_ms) |> Enum.max()
      end

    verdict = classify_health(online, total, avg_load, max_latency)

    %{
      verdict: verdict,
      online_nodes: online,
      total_nodes: total,
      avg_load_pct: avg_load,
      max_latency_ms: max_latency,
      uptime_ms: max(0, now_ms() - state.started_at)
    }
  end

  defp classify_health(0, _total, _load, _lat), do: :critical
  defp classify_health(online, total, _load, _lat) when online < total, do: :degraded
  defp classify_health(_online, _total, load, _lat) when load > 85.0, do: :degraded
  defp classify_health(_online, _total, _load, lat) when lat > 250, do: :degraded
  defp classify_health(_online, _total, _load, _lat), do: :healthy

  defp calc_score(state) do
    health = calc_health(state)

    node_component =
      if health.total_nodes == 0 do
        0.0
      else
        health.online_nodes / health.total_nodes * 50.0
      end

    load_penalty = min(25.0, health.avg_load_pct * 0.25)
    latency_penalty = min(25.0, health.max_latency_ms * 0.1)
    raw = node_component + (25.0 - load_penalty) + (25.0 - latency_penalty)

    raw
    |> max(0.0)
    |> min(100.0)
    |> round_2()
  end

  defp format_status_line(state) do
    health = calc_health(state)
    score = calc_score(state)

    "WMX-EX|#{health.verdict}|score=#{score}|nodes=#{health.online_nodes}/#{health.total_nodes}|" <>
      "load=#{health.avg_load_pct}%|tasks=#{length(state.tasks)}"
  end

  defp render_json_snapshot(state) do
    health = calc_health(state)
    score = calc_score(state)
    summary = summarize_tasks(state.tasks)
    alerts = collect_alerts(state)

    nodes_json =
      state.nodes
      |> Map.values()
      |> Enum.map_join(",", &render_node_json/1)

    tasks_json =
      state.tasks
      |> Enum.map_join(",", &render_task_json/1)

    logs_json =
      state.logs
      |> Enum.map_join(",", &render_log_json/1)

    alerts_json =
      alerts
      |> Enum.map_join(",", fn {nid, reason, val} ->
        "{\"node\":\"#{escape_json(nid)}\",\"reason\":\"#{escape_json(reason)}\",\"value\":\"#{escape_json(val)}\"}"
      end)

    "{" <>
      "\"engine\":\"WMX.Orchestrator\"," <>
      "\"verdict\":\"#{health.verdict}\"," <>
      "\"score\":#{score}," <>
      "\"uptime_ms\":#{health.uptime_ms}," <>
      "\"health\":{" <>
      "\"online_nodes\":#{health.online_nodes}," <>
      "\"total_nodes\":#{health.total_nodes}," <>
      "\"avg_load_pct\":#{health.avg_load_pct}," <>
      "\"max_latency_ms\":#{health.max_latency_ms}" <>
      "}," <>
      "\"tasks_summary\":{" <>
      "\"total\":#{summary.total}," <>
      "\"succeeded\":#{summary.succeeded}," <>
      "\"failed\":#{summary.failed}," <>
      "\"avg_duration_ms\":#{summary.avg_duration_ms}," <>
      "\"total_lines\":#{summary.total_lines}" <>
      "}," <>
      "\"nodes\":[#{nodes_json}]," <>
      "\"tasks\":[#{tasks_json}]," <>
      "\"logs\":[#{logs_json}]," <>
      "\"alerts\":[#{alerts_json}]" <>
      "}"
  end

  defp render_node_json(node) do
    tags_json = Enum.map_join(node.tags, ",", fn t -> "\"#{escape_json(t)}\"" end)

    "{" <>
      "\"id\":\"#{escape_json(node.id)}\"," <>
      "\"kind\":\"#{escape_json(node.kind)}\"," <>
      "\"endpoint\":\"#{escape_json(node.endpoint)}\"," <>
      "\"status\":\"#{escape_json(node.status)}\"," <>
      "\"latency_ms\":#{node.latency_ms}," <>
      "\"load_pct\":#{round_2(node.load_pct)}," <>
      "\"restarts\":#{node.restarts}," <>
      "\"tags\":[#{tags_json}]" <>
      "}"
  end

  defp render_task_json(task) do
    "{" <>
      "\"id\":#{task.id}," <>
      "\"component\":\"#{escape_json(task.component)}\"," <>
      "\"lang\":\"#{escape_json(task.lang)}\"," <>
      "\"duration_ms\":#{task.duration_ms}," <>
      "\"status\":\"#{escape_json(task.status)}\"," <>
      "\"lines\":#{task.lines}," <>
      "\"timestamp\":#{task.timestamp}" <>
      "}"
  end

  defp render_log_json(log) do
    "{" <>
      "\"seq\":#{log.seq}," <>
      "\"level\":\"#{escape_json(log.level)}\"," <>
      "\"message\":\"#{escape_json(log.message)}\"," <>
      "\"timestamp\":#{log.timestamp}" <>
      "}"
  end

  defp escape_json(val) do
    val
    |> to_string()
    |> String.to_charlist()
    |> Enum.map_join(fn
      ?\\ -> "\\\\"
      ?\" -> "\\\""
      ?\b -> "\\b"
      ?\f -> "\\f"
      ?\n -> "\\n"
      ?\r -> "\\r"
      ?\t -> "\\t"
      codepoint when codepoint < 0x20 ->
        "\\u" <> (codepoint |> Integer.to_string(16) |> String.pad_leading(4, "0"))

      codepoint ->
        <<codepoint::utf8>>
    end)
  end

  ## ===================================================================
  ## Language, Alert & Series Analytics
  ## ===================================================================

  def supported_languages, do: @supported_languages

  def supported_language?(lang) when is_atom(lang), do: lang in @supported_languages

  def supported_language?(lang) when is_binary(lang) do
    Enum.any?(@supported_languages, fn item -> Atom.to_string(item) == String.downcase(lang) end)
  end

  def supported_language?(_), do: false

  def language_family(:elm), do: :frontend
  def language_family(:javascript), do: :frontend
  def language_family(:typescript), do: :frontend
  def language_family(:scss), do: :frontend
  def language_family(:erlang), do: :beam
  def language_family(:elixir), do: :beam
  def language_family(:c), do: :systems
  def language_family(:cpp), do: :systems
  def language_family(:rust), do: :systems
  def language_family(:assembly), do: :systems
  def language_family(:pascal), do: :systems
  def language_family(:fortran), do: :numeric
  def language_family(:cobol), do: :core_ledger
  def language_family(:sql), do: :data
  def language_family(:json), do: :data
  def language_family(:python), do: :scripting
  def language_family(:ruby), do: :scripting
  def language_family(:csharp), do: :application
  def language_family(:haskell), do: :functional
  def language_family(_), do: :other

  def languages_by_family do
    Enum.group_by(@supported_languages, &language_family/1)
  end

  def infer_lang_from_component(component) do
    name = component |> to_string() |> String.downcase()

    cond do
      String.contains?(name, "elm") -> :elm
      String.contains?(name, "erlang") or String.ends_with?(name, ".erl") -> :erlang
      String.contains?(name, "elixir") or String.ends_with?(name, ".ex") -> :elixir
      String.contains?(name, "cobol") or String.ends_with?(name, ".cbl") -> :cobol
      String.contains?(name, "fortran") or String.ends_with?(name, ".f90") -> :fortran
      String.contains?(name, "asm") or String.ends_with?(name, ".s") -> :assembly
      String.contains?(name, "ruby") or String.ends_with?(name, ".rb") -> :ruby
      String.contains?(name, "sql") -> :sql
      String.contains?(name, "pascal") or String.ends_with?(name, ".pas") -> :pascal
      String.contains?(name, "rust") or String.ends_with?(name, ".rs") -> :rust
      String.contains?(name, "ts") -> :typescript
      String.contains?(name, "js") -> :javascript
      String.contains?(name, "python") or String.ends_with?(name, ".py") -> :python
      String.contains?(name, "csharp") or String.ends_with?(name, ".cs") -> :csharp
      String.contains?(name, "haskell") or String.ends_with?(name, ".hs") -> :haskell
      String.contains?(name, "scss") -> :scss
      String.contains?(name, "cpp") or String.contains?(name, "c++") -> :cpp
      String.contains?(name, "c_") or String.ends_with?(name, ".c") -> :c
      true -> :json
    end
  end

  def infer_lines(:elm), do: 1481
  def infer_lines(:erlang), do: 800
  def infer_lines(:elixir), do: 800
  def infer_lines(:cobol), do: 4002
  def infer_lines(:fortran), do: 486
  def infer_lines(:assembly), do: 486
  def infer_lines(:ruby), do: 382
  def infer_lines(:sql), do: 354
  def infer_lines(:pascal), do: 280
  def infer_lines(:rust), do: 252
  def infer_lines(:javascript), do: 212
  def infer_lines(:python), do: 196
  def infer_lines(:csharp), do: 180
  def infer_lines(:haskell), do: 174
  def infer_lines(:json), do: 164
  def infer_lines(:c), do: 158
  def infer_lines(:cpp), do: 156
  def infer_lines(:scss), do: 14
  def infer_lines(:typescript), do: 8
  def infer_lines(_), do: 0

  def collect_alerts(%__MODULE__{} = state) do
    state.nodes
    |> Map.values()
    |> Enum.flat_map(&node_alerts/1)
  end

  def node_alerts(node) do
    status_alert =
      if node.status != :online do
        [{node.id, :status_not_online, node.status}]
      else
        []
      end

    latency_alert =
      if node.latency_ms > 200 do
        [{node.id, :high_latency_ms, node.latency_ms}]
      else
        []
      end

    load_alert =
      if node.load_pct > 80.0 do
        [{node.id, :high_load_pct, round_2(node.load_pct)}]
      else
        []
      end

    status_alert ++ latency_alert ++ load_alert
  end

  def series_stats([]), do: %{count: 0, min: 0.0, max: 0.0, avg: 0.0}

  def series_stats(samples) when is_list(samples) do
    vals = Enum.map(samples, fn {_ts, val} -> val * 1.0 end)
    count = length(vals)

    %{
      count: count,
      min: vals |> Enum.min() |> round_2(),
      max: vals |> Enum.max() |> round_2(),
      avg: (Enum.sum(vals) / count) |> round_2()
    }
  end

  def moving_average(samples, window) when is_list(samples) and is_integer(window) and window > 0 do
    slice = Enum.take(samples, window)

    case length(slice) do
      0 ->
        0.0

      n ->
        slice
        |> Enum.map(fn {_ts, val} -> val * 1.0 end)
        |> Enum.sum()
        |> Kernel./(n)
        |> round_2()
    end
  end

  def moving_average(_samples, _window), do: 0.0

  def filter_tasks_by_lang(tasks, lang) when is_list(tasks) do
    Enum.filter(tasks, fn t -> t.lang == lang end)
  end

  def filter_tasks_by_status(tasks, status) when is_list(tasks) do
    Enum.filter(tasks, fn t -> t.status == status end)
  end

  def filter_logs_by_level(logs, level) when is_list(logs) do
    norm = normalize_level(level)
    Enum.filter(logs, fn l -> l.level == norm end)
  end

  def format_node_line(node) do
    "#{node.id} [#{node.status}] lat=#{node.latency_ms}ms load=#{round_2(node.load_pct)}% restarts=#{node.restarts}"
  end

  def format_task_line(task) do
    "##{task.id} #{task.component} (#{task.lang}) -> #{task.status} in #{task.duration_ms}ms (#{task.lines} lines)"
  end

  def format_log_line(log) do
    "[#{log.seq}][#{log.level}] #{log.message}"
  end

  def print_report(server \\ __MODULE__) do
    {:ok, state} = snapshot(server)
    {:ok, line} = status_line(server)
    alerts = collect_alerts(state)
    summary = summarize_tasks(state.tasks)

    IO.puts("=== The Web Machine X v0.2 ===")
    IO.puts("Status : #{line}")
    IO.puts("Tasks  : #{inspect(summary)}")
    IO.puts("Alerts : #{inspect(alerts)}")

    Enum.each(Map.values(state.nodes), fn n ->
      IO.puts("Node   : #{format_node_line(n)}")
    end)

    IO.puts("====================================")
    :ok
  end

  def run_demo do
    {:ok, pid} = start_link(name: nil)
    :ok = record_metric(pid, :elixir_orch, :latency_ms, 2)
    :ok = record_metric(pid, :elixir_orch, :load_pct, 12.4)
    {:ok, _} = record_task(pid, "elm_bundle", 140, :ok, %{lang: :elm, lines: 1481})
    {:ok, _} = record_task(pid, "erlang_beam", 65, :ok, %{lang: :erlang, lines: 800})
    {:ok, _} = record_task(pid, "elixir_orch", 52, :ok, %{lang: :elixir, lines: 800})
    :ok = print_report(pid)
    {:ok, json} = to_json(pid)
    IO.puts(json)
    stop(pid)
  end

  ## ===================================================================
  ## Primitive Converters & Guards
  ## ===================================================================

  defp normalize_map(attrs) when is_map(attrs), do: attrs
  defp normalize_map(attrs) when is_list(attrs), do: Map.new(attrs)
  defp normalize_map(_), do: %{}

  defp normalize_level(:info), do: :info
  defp normalize_level(:warn), do: :warn
  defp normalize_level(:warning), do: :warn
  defp normalize_level(:error), do: :error
  defp normalize_level(:err), do: :error
  defp normalize_level(lvl) when is_binary(lvl) do
    case String.downcase(lvl) do
      "warn" -> :warn
      "warning" -> :warn
      "error" -> :error
      "err" -> :error
      _ -> :info
    end
  end
  defp normalize_level(_), do: :info

  defp normalize_status(:online), do: :online
  defp normalize_status(:degraded), do: :degraded
  defp normalize_status(:offline), do: :offline
  defp normalize_status(:draining), do: :draining
  defp normalize_status(_), do: :online

  defp clamp_pct(val) when is_number(val) do
    val * 1.0
    |> max(0.0)
    |> min(100.0)
  end

  defp clamp_pct(_), do: 0.0

  defp round_2(val) when is_number(val) do
    Float.round(val * 1.0, 2)
  end

    defp now_ms do
    System.monotonic_time(:millisecond)
  end
end

WMX.Orchestrator.run_demo()
