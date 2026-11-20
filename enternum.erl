-module(wmx_engine).
-export([
    main/1,
    start/0,
    stop/1,
    ping/1,
    get_state/1,
    register_node/3,
    unregister_node/2,
    list_nodes/1,
    get_node/2,
    record_metric/4,
    get_metrics/2,
    clear_metrics/1,
    record_build/5,
    list_builds/1,
    build_summary/1,
    append_log/3,
    recent_logs/2,
    evaluate_health/1,
    compute_score/1,
    format_status_line/1,
    encode_json_snapshot/1,
    run_diagnostics/0,
    loop/1
]).

-record(node_info, {
    id,
    kind,
    endpoint,
    status = online,
    latency_ms = 0,
    load_pct = 0.0,
    restarts = 0,
    last_seen = 0,
    tags = []
}).

-record(build_rec, {
    id,
    lang,
    target,
    duration_ms,
    status,
    lines = 0,
    timestamp = 0
}).

-record(log_entry, {
    seq,
    level,
    message,
    timestamp
}).

-record(engine_state, {
    started_at,
    seq_counter = 0,
    nodes = #{},
    metrics = #{},
    builds = [],
    logs = [],
    max_logs = 256,
    max_builds = 128,
    max_samples = 64
}).
%%====================================================================
%% Lifecycle & Client API
%%====================================================================

start() ->
    InitState = #engine_state{
        started_at = monotonic_ms(),
        seq_counter = 0,
        nodes = default_nodes(),
        metrics = #{},
        builds = [],
        logs = []
    },
    Pid = spawn(fun() -> loop(InitState) end),
    Pid ! {append_log, info, "wmx_engine started"},
    {ok, Pid}.

stop(Pid) when is_pid(Pid) ->
    Ref = monitor(process, Pid),
    Pid ! {stop, self(), Ref},
    receive
        {stopped, Ref} ->
            demonitor(Ref, [flush]),
            ok;
        {'DOWN', Ref, process, Pid, Reason} ->
            {error, Reason}
    after 3000 ->
        demonitor(Ref, [flush]),
        {error, timeout}
    end.

ping(Pid) when is_pid(Pid) ->
    call(Pid, ping, 2000).

get_state(Pid) when is_pid(Pid) ->
    call(Pid, get_state, 2000).

register_node(Pid, Id, Opts) when is_pid(Pid) ->
    call(Pid, {register_node, Id, Opts}, 2000).

unregister_node(Pid, Id) when is_pid(Pid) ->
    call(Pid, {unregister_node, Id}, 2000).

list_nodes(Pid) when is_pid(Pid) ->
    call(Pid, list_nodes, 2000).

get_node(Pid, Id) when is_pid(Pid) ->
    call(Pid, {get_node, Id}, 2000).

record_metric(Pid, NodeId, Key, Value) when is_pid(Pid), is_number(Value) ->
    call(Pid, {record_metric, NodeId, Key, Value}, 2000).

get_metrics(Pid, NodeId) when is_pid(Pid) ->
    call(Pid, {get_metrics, NodeId}, 2000).

clear_metrics(Pid) when is_pid(Pid) ->
    call(Pid, clear_metrics, 2000).

record_build(Pid, Lang, Target, DurationMs, Status) when is_pid(Pid) ->
    call(Pid, {record_build, Lang, Target, DurationMs, Status}, 2000).

list_builds(Pid) when is_pid(Pid) ->
    call(Pid, list_builds, 2000).

build_summary(Pid) when is_pid(Pid) ->
    call(Pid, build_summary, 2000).

append_log(Pid, Level, Message) when is_pid(Pid) ->
    call(Pid, {append_log, Level, Message}, 2000).

recent_logs(Pid, Limit) when is_pid(Pid), is_integer(Limit), Limit >= 0 ->
    call(Pid, {recent_logs, Limit}, 2000).

evaluate_health(Pid) when is_pid(Pid) ->
    call(Pid, evaluate_health, 2000).

compute_score(Pid) when is_pid(Pid) ->
    call(Pid, compute_score, 2000).

format_status_line(Pid) when is_pid(Pid) ->
    call(Pid, format_status_line, 2000).

encode_json_snapshot(Pid) when is_pid(Pid) ->
    call(Pid, encode_json_snapshot, 2000).

%%====================================================================
%% Server Loop
%%====================================================================

loop(State) ->
    receive
        {req, From, Tag, ping} ->
            From ! {resp, Tag, {pong, monotonic_ms()}},
            loop(State);

        {req, From, Tag, get_state} ->
            From ! {resp, Tag, {ok, State}},
            loop(State);

        {req, From, Tag, {register_node, Id, Opts}} ->
            {Reply, NextState} = handle_register_node(State, Id, Opts),
            From ! {resp, Tag, Reply},
            loop(NextState);

        {req, From, Tag, {unregister_node, Id}} ->
            {Reply, NextState} = handle_unregister_node(State, Id),
            From ! {resp, Tag, Reply},
            loop(NextState);

        {req, From, Tag, list_nodes} ->
            NodesList = maps:values(State#engine_state.nodes),
            From ! {resp, Tag, {ok, NodesList}},
            loop(State);

        {req, From, Tag, {get_node, Id}} ->
            Reply = case maps:find(Id, State#engine_state.nodes) of
                {ok, N} -> {ok, N};
                error -> {error, not_found}
            end,
            From ! {resp, Tag, Reply},
            loop(State);

        {req, From, Tag, {record_metric, NodeId, Key, Value}} ->
            NextState = handle_record_metric(State, NodeId, Key, Value),
            From ! {resp, Tag, ok},
            loop(NextState);

        {req, From, Tag, {get_metrics, NodeId}} ->
            MMap = maps:get(NodeId, State#engine_state.metrics, #{}),
            From ! {resp, Tag, {ok, MMap}},
            loop(State);

        {req, From, Tag, clear_metrics} ->
            NextState = State#engine_state{metrics = #{}},
            From ! {resp, Tag, ok},
            loop(NextState);

        {req, From, Tag, {record_build, Lang, Target, DurationMs, Status}} ->
            {Rec, NextState} = handle_record_build(State, Lang, Target, DurationMs, Status),
            From ! {resp, Tag, {ok, Rec}},
            loop(NextState);

        {req, From, Tag, list_builds} ->
            From ! {resp, Tag, {ok, State#engine_state.builds}},
            loop(State);

        {req, From, Tag, build_summary} ->
            Summary = summarize_builds(State#engine_state.builds),
            From ! {resp, Tag, {ok, Summary}},
            loop(State);

        {req, From, Tag, {append_log, Level, Message}} ->
            NextState = push_log(State, Level, Message),
            From ! {resp, Tag, ok},
            loop(NextState);

        {req, From, Tag, {recent_logs, Limit}} ->
            Slice = lists:sublist(State#engine_state.logs, Limit),
            From ! {resp, Tag, {ok, Slice}},
            loop(State);

        {req, From, Tag, evaluate_health} ->
            Health = calc_health(State),
            From ! {resp, Tag, {ok, Health}},
            loop(State);

        {req, From, Tag, compute_score} ->
            Score = calc_score(State),
            From ! {resp, Tag, {ok, Score}},
            loop(State);

        {req, From, Tag, format_status_line} ->
            Line = build_status_line(State),
            From ! {resp, Tag, {ok, Line}},
            loop(State);

        {req, From, Tag, encode_json_snapshot} ->
            Json = render_json(State),
            From ! {resp, Tag, {ok, Json}},
            loop(State);

        {append_log, Level, Message} ->
            NextState = push_log(State, Level, Message),
            loop(NextState);

        {stop, From, Ref} ->
            From ! {stopped, Ref},
            ok;

        _Other ->
            loop(State)
    end.

%%====================================================================
%% Internal State Handlers
%%====================================================================

call(Pid, Msg, Timeout) ->
    Tag = make_ref(),
    Pid ! {req, self(), Tag, Msg},
    receive
        {resp, Tag, Reply} -> Reply
    after Timeout ->
        {error, timeout}
    end.

default_nodes() ->
    Now = monotonic_ms(),
    #{
        elm_ui => #node_info{
            id = elm_ui,
            kind = frontend,
            endpoint = "browser://web-machine-x.js",
            status = online,
            latency_ms = 2,
            load_pct = 12.0,
            last_seen = Now,
            tags = [elm, html, css]
        },
        beam_core => #node_info{
            id = beam_core,
            kind = runtime,
            endpoint = "beam://localhost:4000",
            status = online,
            latency_ms = 4,
            load_pct = 18.5,
            last_seen = Now,
            tags = [erlang, elixir, otp]
        },
        sys_worker => #node_info{
            id = sys_worker,
            kind = native,
            endpoint = "local://wmx-sys",
            status = online,
            latency_ms = 1,
            load_pct = 9.0,
            last_seen = Now,
            tags = [c, rust, pascal, cobol]
        }
    }.

handle_register_node(State, Id, Opts) when is_map(Opts) ->
    Now = monotonic_ms(),
    Kind = maps:get(kind, Opts, worker),
    Endpoint = maps:get(endpoint, Opts, "local://node"),
    Status = maps:get(status, Opts, online),
    Latency = maps:get(latency_ms, Opts, 5),
    Load = maps:get(load_pct, Opts, 0.0),
    Tags = maps:get(tags, Opts, []),
    Existing = maps:find(Id, State#engine_state.nodes),
    Restarts = case Existing of
        {ok, #node_info{restarts = R}} -> R + 1;
        error -> 0
    end,
    Rec = #node_info{
        id = Id,
        kind = Kind,
        endpoint = Endpoint,
        status = Status,
        latency_ms = Latency,
        load_pct = float(Load),
        restarts = Restarts,
        last_seen = Now,
        tags = Tags
    },
    Nodes1 = maps:put(Id, Rec, State#engine_state.nodes),
    State1 = push_log(State#engine_state{nodes = Nodes1}, info,
                      io_lib:format("node registered: ~p", [Id])),
    {{ok, Rec}, State1};
handle_register_node(State, Id, Opts) when is_list(Opts) ->
    handle_register_node(State, Id, maps:from_list(Opts)).

handle_unregister_node(State, Id) ->
    case maps:is_key(Id, State#engine_state.nodes) of
        true ->
            Nodes1 = maps:remove(Id, State#engine_state.nodes),
            State1 = push_log(State#engine_state{nodes = Nodes1}, warn,
                              io_lib:format("node unregistered: ~p", [Id])),
            {ok, State1};
        false ->
            {{error, not_found}, State}
    end.

handle_record_metric(State, NodeId, Key, Value) ->
    MaxSamples = State#engine_state.max_samples,
    Metrics0 = State#engine_state.metrics,
    NodeMetrics0 = maps:get(NodeId, Metrics0, #{}),
    Series0 = maps:get(Key, NodeMetrics0, []),
    Sample = {monotonic_ms(), Value * 1.0},
    Series1 = bounded_cons(Sample, Series0, MaxSamples),
    NodeMetrics1 = maps:put(Key, Series1, NodeMetrics0),
    Metrics1 = maps:put(NodeId, NodeMetrics1, Metrics0),
    Nodes1 = update_node_telemetry(State#engine_state.nodes, NodeId, Key, Value),
    State#engine_state{metrics = Metrics1, nodes = Nodes1}.

update_node_telemetry(Nodes, NodeId, latency_ms, Value) ->
    case maps:find(NodeId, Nodes) of
        {ok, N} ->
            N1 = N#node_info{latency_ms = round(Value), last_seen = monotonic_ms()},
            maps:put(NodeId, N1, Nodes);
        error ->
            Nodes
    end;
update_node_telemetry(Nodes, NodeId, load_pct, Value) ->
    case maps:find(NodeId, Nodes) of
        {ok, N} ->
            N1 = N#node_info{load_pct = Value * 1.0, last_seen = monotonic_ms()},
            maps:put(NodeId, N1, Nodes);
        error ->
            Nodes
    end;
update_node_telemetry(Nodes, NodeId, _Key, _Value) ->
    case maps:find(NodeId, Nodes) of
        {ok, N} ->
            N1 = N#node_info{last_seen = monotonic_ms()},
            maps:put(NodeId, N1, Nodes);
        error ->
            Nodes
    end.

handle_record_build(State, Lang, Target, DurationMs, Status) ->
    Seq = State#engine_state.seq_counter + 1,
    Now = monotonic_ms(),
    Lines = infer_lines_for_lang(Lang),
    Rec = #build_rec{
        id = Seq,
        lang = Lang,
        target = Target,
        duration_ms = DurationMs,
        status = Status,
        lines = Lines,
        timestamp = Now
    },
    Builds1 = bounded_cons(Rec, State#engine_state.builds, State#engine_state.max_builds),
    LogLevel = case Status of
        ok -> info;
        success -> info;
        _ -> error
    end,
    Msg = io_lib:format("build #~p [~p -> ~p] ~p in ~pms",
                        [Seq, Lang, Target, Status, DurationMs]),
    State1 = push_log(State#engine_state{seq_counter = Seq, builds = Builds1},
                      LogLevel, Msg),
    {Rec, State1}.

push_log(State, Level, Message) ->
    Seq = State#engine_state.seq_counter + 1,
    Entry = #log_entry{
        seq = Seq,
        level = Level,
        message = lists:flatten(io_lib:format("~s", [Message])),
        timestamp = monotonic_ms()
    },
    Logs1 = bounded_cons(Entry, State#engine_state.logs, State#engine_state.max_logs),
    State#engine_state{seq_counter = Seq, logs = Logs1}.

bounded_cons(Item, List, MaxLen) when MaxLen > 0 ->
    Trimmed = if
        length(List) >= MaxLen -> lists:sublist(List, MaxLen - 1);
        true -> List
    end,
    [Item | Trimmed].

%%====================================================================
%% Analytics, Health & Formatting
%%====================================================================

summarize_builds(Builds) ->
    Total = length(Builds),
    OkCount = length([B || #build_rec{status = S} = B <- Builds, S =:= ok orelse S =:= success]),
    ErrCount = Total - OkCount,
    TotalMs = lists:sum([D || #build_rec{duration_ms = D} <- Builds]),
    AvgMs = case Total of
        0 -> 0.0;
        _ -> TotalMs / Total
    end,
    TotalLines = lists:sum([L || #build_rec{lines = L} <- Builds]),
    #{
        total => Total,
        succeeded => OkCount,
        failed => ErrCount,
        avg_duration_ms => round_2(AvgMs),
        total_lines_built => TotalLines
    }.

calc_health(State) ->
    Nodes = maps:values(State#engine_state.nodes),
    TotalNodes = length(Nodes),
    OnlineNodes = length([N || #node_info{status = online} = N <- Nodes]),
    AvgLoad = case TotalNodes of
        0 -> 0.0;
        _ -> lists:sum([L || #node_info{load_pct = L} <- Nodes]) / TotalNodes
    end,
    MaxLatency = case Nodes of
        [] -> 0;
        _ -> lists:max([Lat || #node_info{latency_ms = Lat} <- Nodes])
    end,
    Verdict = classify_health(OnlineNodes, TotalNodes, AvgLoad, MaxLatency),
    #{
        verdict => Verdict,
        online_nodes => OnlineNodes,
        total_nodes => TotalNodes,
        avg_load_pct => round_2(AvgLoad),
        max_latency_ms => MaxLatency,
        uptime_ms => monotonic_ms() - State#engine_state.started_at
    }.

classify_health(0, _, _, _) -> critical;
classify_health(Online, Total, _, _) when Online < Total -> degraded;
classify_health(_, _, AvgLoad, _) when AvgLoad > 85.0 -> degraded;
classify_health(_, _, _, Lat) when Lat > 250 -> degraded;
classify_health(_, _, _, _) -> healthy.

calc_score(State) ->
    Health = calc_health(State),
    #{
        online_nodes := Online,
        total_nodes := Total,
        avg_load_pct := Load,
        max_latency_ms := Lat
    } = Health,
    NodeRatio = case Total of
        0 -> 0.0;
        _ -> (Online / Total) * 50.0
    end,
    LoadPenalty = min_float(25.0, Load * 0.25),
    LatPenalty = min_float(25.0, Lat * 0.1),
    Raw = NodeRatio + (25.0 - LoadPenalty) + (25.0 - LatPenalty),
    round_2(max_float(0.0, min_float(100.0, Raw))).

build_status_line(State) ->
    Health = calc_health(State),
    Score = calc_score(State),
    #{
        verdict := Verdict,
        online_nodes := Online,
        total_nodes := Total,
        avg_load_pct := Load
    } = Health,
    lists:flatten(io_lib:format(
        "WMX|~p|score=~p|nodes=~p/~p|load=~p%|builds=~p",
        [Verdict, Score, Online, Total, Load, length(State#engine_state.builds)]
    )).

render_json(State) ->
    Health = calc_health(State),
    Score = calc_score(State),
    Summary = summarize_builds(State#engine_state.builds),
    #{
        verdict := Verdict,
        online_nodes := Online,
        total_nodes := Total,
        avg_load_pct := Load,
        max_latency_ms := Lat,
        uptime_ms := Uptime
    } = Health,
    #{
        total := BuildTotal,
        succeeded := BuildOk,
        failed := BuildErr,
        avg_duration_ms := AvgBuildMs
    } = Summary,
    lists:flatten(io_lib:format(
        "{\"verdict\":\"~p\",\"score\":~p,\"nodes\":{\"online\":~p,\"total\":~p,"
        "\"avg_load_pct\":~p,\"max_latency_ms\":~p},\"builds\":{\"total\":~p,"
        "\"succeeded\":~p,\"failed\":~p,\"avg_duration_ms\":~p},\"uptime_ms\":~p}",
        [Verdict, Score, Online, Total, Load, Lat,
         BuildTotal, BuildOk, BuildErr, AvgBuildMs, Uptime]
    )).

infer_lines_for_lang(elm) -> 1481;
infer_lines_for_lang(erlang) -> 800;
infer_lines_for_lang(cobol) -> 4002;
infer_lines_for_lang(fortran) -> 486;
infer_lines_for_lang(assembly) -> 486;
infer_lines_for_lang(ruby) -> 382;
infer_lines_for_lang(sql) -> 354;
infer_lines_for_lang(pascal) -> 280;
infer_lines_for_lang(rust) -> 252;
infer_lines_for_lang(javascript) -> 212;
infer_lines_for_lang(python) -> 196;
infer_lines_for_lang(csharp) -> 180;
infer_lines_for_lang(haskell) -> 174;
infer_lines_for_lang(json) -> 164;
infer_lines_for_lang(c) -> 158;
infer_lines_for_lang(cpp) -> 156;
infer_lines_for_lang(scss) -> 14;
infer_lines_for_lang(typescript) -> 8;
infer_lines_for_lang(_) -> 0.

monotonic_ms() ->
    erlang:monotonic_time(millisecond).

min_float(A, B) when A =< B -> float(A);
min_float(_, B) -> float(B).

max_float(A, B) when A >= B -> float(A);
max_float(_, B) -> float(B).

round_2(Val) ->
    round(Val * 100.0) / 100.0.

%%====================================================================
%% Diagnostics Runner
%%====================================================================

main(_Args) ->
    #{status_line := Line, json := Json} = run_diagnostics(),
    io:format("The Web Machine X v0.2~n~s~n~s~n", [Line, Json]),
    ok.

run_diagnostics() ->
    {ok, Pid} = start(),
    pong_check(ping(Pid)),
    {ok, _} = register_node(Pid, elixir_api, #{
        kind => service,
        endpoint => "beam://localhost:4001",
        latency_ms => 6,
        load_pct => 21.0,
        tags => [elixir, phoenix]
    }),
    ok = record_metric(Pid, beam_core, latency_ms, 5),
    ok = record_metric(Pid, beam_core, load_pct, 19.2),
    {ok, _} = record_build(Pid, elm, "web-machine-x.js", 140, ok),
    {ok, _} = record_build(Pid, erlang, "wmx_engine.beam", 65, ok),
    ok = append_log(Pid, info, "diagnostics completed"),
    {ok, Line} = format_status_line(Pid),
    {ok, Json} = encode_json_snapshot(Pid),
    ok = stop(Pid),
    #{status_line => Line, json => Json}.

pong_check({pong, _}) -> ok;
pong_check(Other) -> exit({unexpected_pong, Other}).

%% Helper functions for numeric aggregation and filtering
series_stats([]) ->
    #{count => 0, min => 0.0, max => 0.0, avg => 0.0};
series_stats(Samples) ->
    Vals = [V || {_Ts, V} <- Samples],
    Count = length(Vals),
    MinV = lists:min(Vals),
    MaxV = lists:max(Vals),
    AvgV = lists:sum(Vals) / Count,
    #{
        count => Count,
        min => round_2(MinV),
        max => round_2(MaxV),
        avg => round_2(AvgV)
    }.

filter_builds_by_lang(Builds, Lang) ->
    [B || #build_rec{lang = L} = B <- Builds, L =:= Lang].

filter_builds_by_status(Builds, Status) ->
    [B || #build_rec{status = S} = B <- Builds, S =:= Status].

filter_logs_by_level(Logs, Level) ->
    [L || #log_entry{level = Lv} = L <- Logs, Lv =:= Level].

active_node_count(State) ->
    length([N || #node_info{status = online} = N <- maps:values(State#engine_state.nodes)]).

total_node_restarts(State) ->
    lists:sum([R || #node_info{restarts = R} <- maps:values(State#engine_state.nodes)]).

find_hottest_node(State) ->
    Nodes = maps:values(State#engine_state.nodes),
    case Nodes of
        [] -> none;
        _ ->
            Sorted = lists:sort(
                fun(#node_info{load_pct = A}, #node_info{load_pct = B}) -> A >= B end,
                Nodes
            ),
            {ok, hd(Sorted)}
    end.

find_slowest_node(State) ->
    Nodes = maps:values(State#engine_state.nodes),
    case Nodes of
        [] -> none;
        _ ->
            Sorted = lists:sort(
                fun(#node_info{latency_ms = A}, #node_info{latency_ms = B}) -> A >= B end,
                Nodes
            ),
            {ok, hd(Sorted)}
    end.

format_node_summary(#node_info{id = Id, status = St, latency_ms = Lat, load_pct = Load}) ->
    lists:flatten(io_lib:format("~p (~p): lat=~pms load=~p%", [Id, St, Lat, round_2(Load)])).

format_build_summary(#build_rec{id = Id, lang = Lang, target = Tgt, duration_ms = Ms, status = St}) ->
    lists:flatten(io_lib:format("#~p [~p] ~s -> ~p (~pms)", [Id, Lang, Tgt, St, Ms])).

format_log_summary(#log_entry{seq = Seq, level = Lv, message = Msg}) ->
    lists:flatten(io_lib:format("[~p][~p] ~s", [Seq, Lv, Msg])).

normalize_level(info) -> info;
normalize_level(warn) -> warn;
normalize_level(warning) -> warn;
normalize_level(error) -> error;
normalize_level(err) -> error;
normalize_level(_) -> info.

is_valid_status(online) -> true;
is_valid_status(degraded) -> true;
is_valid_status(offline) -> true;
is_valid_status(draining) -> true;
is_valid_status(_) -> false.

safe_div(_Num, 0) -> 0.0;
safe_div(_Num, +0.0) -> 0.0;
safe_div(Num, Den) -> Num / Den.

clamp_pct(Val) when Val < 0.0 -> 0.0;
clamp_pct(Val) when Val > 100.0 -> 100.0;
clamp_pct(Val) -> float(Val).

%% Extended telemetry & batch operations for polyglot pipelines
batch_record_metrics(Pid, Entries) when is_pid(Pid), is_list(Entries) ->
    lists:foreach(
        fun({NodeId, Key, Value}) ->
            _ = record_metric(Pid, NodeId, Key, Value)
        end,
        Entries
    ),
    ok.

batch_record_builds(Pid, BuildSpecs) when is_pid(Pid), is_list(BuildSpecs) ->
    Results = lists:map(
        fun({Lang, Target, DurationMs, Status}) ->
            record_build(Pid, Lang, Target, DurationMs, Status)
        end,
        BuildSpecs
    ),
    {ok, Results}.

node_ids(State) ->
    maps:keys(State#engine_state.nodes).

has_node(State, Id) ->
    maps:is_key(Id, State#engine_state.nodes).

set_node_status(Nodes, Id, NewStatus) ->
    case {maps:find(Id, Nodes), is_valid_status(NewStatus)} of
        {{ok, N}, true} ->
            N1 = N#node_info{status = NewStatus, last_seen = monotonic_ms()},
            {ok, maps:put(Id, N1, Nodes)};
        {{ok, _}, false} ->
            {error, invalid_status};
        {error, _} ->
            {error, not_found}
    end.

tag_node(Nodes, Id, Tag) ->
    case maps:find(Id, Nodes) of
        {ok, #node_info{tags = Tags} = N} ->
            Tags1 = case lists:member(Tag, Tags) of
                true -> Tags;
                false -> [Tag | Tags]
            end,
            {ok, maps:put(Id, N#node_info{tags = Tags1}, Nodes)};
        error ->
            {error, not_found}
    end.

untag_node(Nodes, Id, Tag) ->
    case maps:find(Id, Nodes) of
        {ok, #node_info{tags = Tags} = N} ->
            Tags1 = lists:delete(Tag, Tags),
            {ok, maps:put(Id, N#node_info{tags = Tags1}, Nodes)};
        error ->
            {error, not_found}
    end.

nodes_with_tag(State, Tag) ->
    [N || #node_info{tags = Tags} = N <- maps:values(State#engine_state.nodes),
          lists:member(Tag, Tags)].

count_builds_by_lang(Builds) ->
    lists:foldl(
        fun(#build_rec{lang = Lang}, Acc) ->
            maps:update_with(Lang, fun(C) -> C + 1 end, 1, Acc)
        end,
        #{},
        Builds
    ).

total_build_lines_by_lang(Builds) ->
    lists:foldl(
        fun(#build_rec{lang = Lang, lines = Lines}, Acc) ->
            maps:update_with(Lang, fun(L) -> L + Lines end, Lines, Acc)
        end,
        #{},
        Builds
    ).

latest_build_for_lang([], _Lang) ->
    none;
latest_build_for_lang([#build_rec{lang = Lang} = B | _], Lang) ->
    {ok, B};
latest_build_for_lang([_ | Rest], Lang) ->
    latest_build_for_lang(Rest, Lang).

prune_old_logs(Logs, MaxKeep) when is_integer(MaxKeep), MaxKeep >= 0 ->
    lists:sublist(Logs, MaxKeep).

format_all_nodes(State) ->
    Lines = [format_node_summary(N) || N <- maps:values(State#engine_state.nodes)],
    string:join(Lines, " | ").

format_all_builds(State) ->
    Lines = [format_build_summary(B) || B <- State#engine_state.builds],
    string:join(Lines, "\n").

format_all_logs(State) ->
    Lines = [format_log_summary(L) || L <- State#engine_state.logs],
    string:join(Lines, "\n").

escape_json_str(Str) when is_list(Str) ->
    lists:flatmap(
        fun
            ($" ) -> "\\\"";
            ($\\) -> "\\\\";
            ($\n) -> "\\n";
            ($\r) -> "\\r";
            ($\t) -> "\\t";
            (Ch) -> [Ch]
        end,
        Str
    );
escape_json_str(Other) ->
    escape_json_str(lists:flatten(io_lib:format("~p", [Other]))).

render_node_json(#node_info{
    id = Id,
    kind = Kind,
    endpoint = Ep,
    status = St,
    latency_ms = Lat,
    load_pct = Load,
    restarts = Restarts
}) ->
    io_lib:format(
        "{\"id\":\"~s\",\"kind\":\"~s\",\"endpoint\":\"~s\",\"status\":\"~s\","
        "\"latency_ms\":~p,\"load_pct\":~p,\"restarts\":~p}",
        [
            escape_json_str(atom_to_list(Id)),
            escape_json_str(atom_to_list(Kind)),
            escape_json_str(Ep),
            escape_json_str(atom_to_list(St)),
            Lat,
            round_2(Load),
            Restarts
        ]
    ).

render_build_json(#build_rec{
    id = Id,
    lang = Lang,
    target = Tgt,
    duration_ms = Ms,
    status = St,
    lines = Lines,
    timestamp = Ts
}) ->
    io_lib:format(
        "{\"id\":~p,\"lang\":\"~s\",\"target\":\"~s\",\"duration_ms\":~p,"
        "\"status\":\"~s\",\"lines\":~p,\"timestamp\":~p}",
        [
            Id,
            escape_json_str(atom_to_list(Lang)),
            escape_json_str(Tgt),
            Ms,
            escape_json_str(atom_to_list(St)),
            Lines,
            Ts
        ]
    ).

render_log_json(#log_entry{
    seq = Seq,
    level = Lv,
    message = Msg,
    timestamp = Ts
}) ->
    io_lib:format(
        "{\"seq\":~p,\"level\":\"~s\",\"message\":\"~s\",\"timestamp\":~p}",
        [
            Seq,
            escape_json_str(atom_to_list(Lv)),
            escape_json_str(Msg),
            Ts
        ]
    ).

render_nodes_array(State) ->
    Items = [render_node_json(N) || N <- maps:values(State#engine_state.nodes)],
    "[" ++ string:join([lists:flatten(I) || I <- Items], ",") ++ "]".

render_builds_array(State) ->
    Items = [render_build_json(B) || B <- State#engine_state.builds],
    "[" ++ string:join([lists:flatten(I) || I <- Items], ",") ++ "]".

render_logs_array(State) ->
    Items = [render_log_json(L) || L <- State#engine_state.logs],
    "[" ++ string:join([lists:flatten(I) || I <- Items], ",") ++ "]".

render_full_json(State) ->
    Health = calc_health(State),
    Score = calc_score(State),
    #{
        verdict := Verdict,
        online_nodes := Online,
        total_nodes := Total,
        avg_load_pct := Load,
        max_latency_ms := Lat,
        uptime_ms := Uptime
    } = Health,
    lists:flatten(io_lib:format(
        "{\"verdict\":\"~s\",\"score\":~p,\"uptime_ms\":~p,"
        "\"health\":{\"online\":~p,\"total\":~p,\"avg_load_pct\":~p,\"max_latency_ms\":~p},"
        "\"nodes\":~s,\"builds\":~s,\"logs\":~s}",
        [
            escape_json_str(atom_to_list(Verdict)),
            Score,
            Uptime,
            Online,
            Total,
            Load,
            Lat,
            render_nodes_array(State),
            render_builds_array(State),
            render_logs_array(State)
        ]
    )).

%% Additional pipeline helpers for cross-language manifest checks
supported_languages() ->
    [
        elm, erlang, elixir, cobol, fortran, assembly,
        ruby, sql, pascal, rust, javascript, python,
        csharp, haskell, json, c, cpp, scss, typescript
    ].

is_supported_language(Lang) ->
    lists:member(Lang, supported_languages()).

language_category(elm) -> frontend;
language_category(javascript) -> frontend;
language_category(typescript) -> frontend;
language_category(scss) -> frontend;
language_category(erlang) -> beam;
language_category(elixir) -> beam;
language_category(c) -> systems;
language_category(cpp) -> systems;
language_category(rust) -> systems;
language_category(assembly) -> systems;
language_category(pascal) -> systems;
language_category(fortran) -> numeric;
language_category(cobol) -> legacy_core;
language_category(sql) -> data;
language_category(json) -> data;
language_category(python) -> scripting;
language_category(ruby) -> scripting;
language_category(csharp) -> application;
language_category(haskell) -> functional;
language_category(_) -> unknown.

group_languages_by_category() ->
    lists:foldl(
        fun(Lang, Acc) ->
            Cat = language_category(Lang),
            maps:update_with(Cat, fun(List) -> [Lang | List] end, [Lang], Acc)
        end,
        #{},
        supported_languages()
    ).

%% Rolling window helpers for metrics
latest_sample([]) ->
    none;
latest_sample([{Ts, Val} | _]) ->
    {ok, {Ts, Val}}.

window_values(Samples, N) when is_integer(N), N >= 0 ->
    [Val || {_Ts, Val} <- lists:sublist(Samples, N)].

moving_average([], _N) ->
    0.0;
moving_average(_Samples, 0) ->
    0.0;
moving_average(Samples, N) ->
    Vals = window_values(Samples, N),
    case length(Vals) of
        0 -> 0.0;
        Len -> round_2(lists:sum(Vals) / Len)
    end.

delta_last_two([{_, V1}, {_, V2} | _]) ->
    {ok, round_2(V1 - V2)};
delta_last_two(_) ->
    none.

spike_detected(Samples, Threshold) when is_number(Threshold) ->
    case delta_last_two(Samples) of
        {ok, Delta} when Delta > Threshold -> true;
        _ -> false
    end.

%% Alert rule evaluation for node telemetry
check_node_alerts(#node_info{id = Id, status = Status, latency_ms = Lat, load_pct = Load}) ->
    A1 = case Status of
        online -> [];
        _ -> [{Id, status_not_online, Status}]
    end,
    A2 = if
        Lat > 200 -> [{Id, high_latency, Lat} | A1];
        true -> A1
    end,
    A3 = if
        Load > 80.0 -> [{Id, high_load, round_2(Load)} | A2];
        true -> A2
    end,
    lists:reverse(A3).

collect_all_alerts(State) ->
    lists:flatmap(
        fun(Node) -> check_node_alerts(Node) end,
        maps:values(State#engine_state.nodes)
    ).

has_critical_alerts(State) ->
    Alerts = collect_all_alerts(State),
    lists:any(
        fun
            ({_Id, status_not_online, _}) -> true;
            ({_Id, high_load, Load}) when Load > 95.0 -> true;
            (_) -> false
        end,
        Alerts
    ).

%% Snapshot rotation and reset utilities
reset_counters(State) ->
    State#engine_state{
        seq_counter = 0,
        builds = [],
        logs = [],
        metrics = #{}
    }.

snapshot_meta(State) ->
    #{
        started_at => State#engine_state.started_at,
        seq_counter => State#engine_state.seq_counter,
        node_count => maps:size(State#engine_state.nodes),
        build_count => length(State#engine_state.builds),
        log_count => length(State#engine_state.logs)
    }.

%% Pretty printer for terminal inspection on Fedora
print_report(Pid) when is_pid(Pid) ->
    {ok, State} = get_state(Pid),
    io:format("=== Web Machine X BEAM Report ===~n"),
    io:format("Status : ~s~n", [build_status_line(State)]),
    io:format("Nodes  : ~s~n", [format_all_nodes(State)]),
    io:format("Alerts : ~p~n", [collect_all_alerts(State)]),
    io:format("Builds : ~p~n", [summarize_builds(State#engine_state.builds)]),
    io:format("=================================~n"),
    ok.

%% Safe wrapper to run diagnostics and print report
demo() ->
    {ok, Pid} = start(),
    _ = record_metric(Pid, beam_core, latency_ms, 3),
    _ = record_metric(Pid, beam_core, load_pct, 14.5),
    _ = record_build(Pid, erlang, "wmx_engine.beam", 48, ok),
    _ = print_report(Pid),
    stop(Pid).