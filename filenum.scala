/*
 * The Web Machine X — Scala Core
 * File: filenum.scala
 * Purpose: A dependency-free Scala 3 reference core for immutable workspace
 * models, configuration, module lifecycle, events, memory accounting,
 * browser abstractions, multiverse workspaces, diagnostics, and utilities.
 *
 * This is an application-layer foundation, not a complete web browser.
 * Network and rendering backends are interfaces for future implementations.
 */
import java.time.Instant
import java.util.UUID
import java.util.concurrent.atomic.AtomicLong
import scala.collection.mutable
import scala.util.Try

object WebMachineXScalaCore:
  val ProductName = "The Web Machine X"
  val Version = "0.2"
  val DefaultMaxTabs = 32
  val DefaultMemoryBudget: Long = 512L * 1024L * 1024L

  enum LogLevel:
    case Trace, Debug, Info, Warn, Error

  enum ModuleState:
    case Created, Starting, Running, Stopping, Stopped, Failed

  enum WorldState:
    case Active, Paused, Archived

  enum ResourceKind:
    case Document, Script, Style, Image, Font, Other

  final case class Outcome[+A](value: Option[A], message: String):
    def isSuccess: Boolean = value.isDefined
    def map[B](f: A => B): Outcome[B] = value match
      case Some(item) => Outcome.success(f(item))
      case None       => Outcome.failure(message)

  object Outcome:
    def success[A](value: A): Outcome[A] = Outcome(Some(value), "ok")
    def failure[A](message: String): Outcome[A] = Outcome(None, message)

  trait Clock:
    def now(): Instant

  object SystemClock extends Clock:
    override def now(): Instant = Instant.now()

  final case class LogEntry(
      time: Instant,
      level: LogLevel,
      area: String,
      message: String,
      context: Map[String, String]
  )

  final class Diagnostics(clock: Clock = SystemClock):
    private val entries = mutable.ArrayBuffer.empty[LogEntry]
    private var threshold = LogLevel.Info

    def setThreshold(level: LogLevel): Unit = synchronized:
      threshold = level

    def log(
        level: LogLevel,
        area: String,
        message: String,
        context: Map[String, String] = Map.empty
    ): Unit = synchronized:
      if level.ordinal >= threshold.ordinal then
        entries += LogEntry(clock.now(), level, area, message, context)

    def snapshot(): Vector[LogEntry] = synchronized:
      entries.toVector

    def recent(count: Int): Vector[LogEntry] = synchronized:
      if count <= 0 then Vector.empty
      else entries.takeRight(count).toVector

    def count(level: LogLevel): Int = synchronized:
      entries.count(_.level == level)

    def clear(): Unit = synchronized:
      entries.clear()

  final case class CoreConfig(
      profile: String = "default",
      maxTabs: Int = DefaultMaxTabs,
      memoryBudgetBytes: Long = DefaultMemoryBudget,
      privateMode: Boolean = false,
      diagnosticsEnabled: Boolean = true
  ):
    require(profile.trim.nonEmpty, "profile cannot be blank")
    require(maxTabs >= 1 && maxTabs <= 512, "maxTabs must be 1..512")
    require(memoryBudgetBytes >= 16L * 1024L * 1024L,
      "memory budget is too small")

    def withPrivateMode(enabled: Boolean): CoreConfig =
      copy(privateMode = enabled)

  trait ConfigStore:
    def read(key: String): Option[String]
    def write(key: String, value: String): Unit
    def remove(key: String): Unit

  final class MemoryConfigStore extends ConfigStore:
    private val values = mutable.Map.empty[String, String]

    override def read(key: String): Option[String] = synchronized:
      values.get(key)

    override def write(key: String, value: String): Unit = synchronized:
      values.update(key, value)

    override def remove(key: String): Unit = synchronized:
      values.remove(key)
      ()

    def snapshot(): Map[String, String] = synchronized:
      values.toMap

  trait CoreModule:
    def id: String
    def description: String
    def start(context: CoreContext): Unit
    def stop(): Unit

  final case class ModuleInfo(
      id: String,
      description: String,
      state: ModuleState,
      changedAt: Instant
  )

  final class ModuleRegistry(
      diagnostics: Diagnostics,
      clock: Clock = SystemClock
  ):
    private val modules = mutable.LinkedHashMap.empty[String, CoreModule]
    private val states = mutable.Map.empty[String, ModuleState]

    def register(module: CoreModule): Outcome[Boolean] = synchronized:
      if module.id.trim.isEmpty then Outcome.failure("module id is required")
      else if modules.contains(module.id) then
        Outcome.failure(s"duplicate module: ${module.id}")
      else
        modules.update(module.id, module)
        states.update(module.id, ModuleState.Created)
        diagnostics.log(LogLevel.Info, "modules", s"registered ${module.id}")
        Outcome.success(true)

    def start(id: String, context: CoreContext): Outcome[Boolean] = synchronized:
      modules.get(id) match
        case None => Outcome.failure(s"unknown module: $id")
        case Some(module) if states(id) == ModuleState.Running =>
          Outcome.success(true)
        case Some(module) =>
          states.update(id, ModuleState.Starting)
          Try(module.start(context)) match
            case scala.util.Success(_) =>
              states.update(id, ModuleState.Running)
              diagnostics.log(LogLevel.Info, "modules", s"started $id")
              Outcome.success(true)
            case scala.util.Failure(error) =>
              states.update(id, ModuleState.Failed)
              diagnostics.log(LogLevel.Error, "modules",
                s"failed to start $id",
                Map("reason" -> Option(error.getMessage).getOrElse("unknown")))
              Outcome.failure(s"module start failed: $id")

    def stop(id: String): Outcome[Boolean] = synchronized:
      modules.get(id) match
        case None => Outcome.failure(s"unknown module: $id")
        case Some(module) if states(id) == ModuleState.Stopped =>
          Outcome.success(true)
        case Some(module) =>
          states.update(id, ModuleState.Stopping)
          Try(module.stop()) match
            case scala.util.Success(_) =>
              states.update(id, ModuleState.Stopped)
              diagnostics.log(LogLevel.Info, "modules", s"stopped $id")
              Outcome.success(true)
            case scala.util.Failure(_) =>
              states.update(id, ModuleState.Failed)
              Outcome.failure(s"module stop failed: $id")

    def list(): Vector[ModuleInfo] = synchronized:
      modules.values.toVector.map { module =>
        ModuleInfo(module.id, module.description, states(module.id), clock.now())
      }

    def find(id: String): Option[CoreModule] = synchronized:
      modules.get(id)

  final case class CoreEvent(
      eventType: String,
      time: Instant,
      source: String,
      payload: Map[String, String]
  )

  final class EventBus(
      clock: Clock = SystemClock,
      diagnostics: Diagnostics
  ):
    private val listeners =
      mutable.Map.empty[String, mutable.ArrayBuffer[CoreEvent => Unit]]

    def subscribe(
        eventType: String,
        listener: CoreEvent => Unit
    ): () => Unit = synchronized:
      val group = listeners.getOrElseUpdate(
        eventType, mutable.ArrayBuffer.empty[CoreEvent => Unit])
      group += listener
      () => synchronized {
        listeners.get(eventType).foreach(_ -= listener)
      }

    def publish(
        eventType: String,
        source: String,
        payload: Map[String, String] = Map.empty
    ): Unit =
      val event = CoreEvent(eventType, clock.now(), source, payload)
      val current = synchronized:
        listeners.get(eventType).map(_.toVector).getOrElse(Vector.empty)
      current.foreach { listener =>
        Try(listener(event)).failed.foreach { error =>
          diagnostics.log(LogLevel.Error, "events",
            s"listener failed for $eventType",
            Map("reason" -> Option(error.getMessage).getOrElse("unknown")))
        }
      }

    def listenerCount(eventType: String): Int = synchronized:
      listeners.get(eventType).fold(0)(_.size)

  final case class MemorySnapshot(
      usedBytes: Long,
      budgetBytes: Long,
      allocations: Int,
      utilization: Double
  )

  final class MemoryLedger(val budgetBytes: Long):
    require(budgetBytes > 0, "budget must be positive")
    private val allocations = mutable.Map.empty[String, Long]
    private var usedBytes = 0L

    def reserve(owner: String, bytes: Long): Outcome[Boolean] = synchronized:
      if owner.trim.isEmpty then Outcome.failure("owner required")
      else if bytes <= 0 then Outcome.failure("bytes must be positive")
      else
        val previous = allocations.getOrElse(owner, 0L)
        val next = usedBytes - previous + bytes
        if next > budgetBytes then Outcome.failure("memory budget exceeded")
        else
          allocations.update(owner, bytes)
          usedBytes = next
          Outcome.success(true)

    def release(owner: String): Unit = synchronized:
      allocations.remove(owner).foreach(bytes => usedBytes -= bytes)

    def releaseAll(): Unit = synchronized:
      allocations.clear()
      usedBytes = 0L

    def snapshot(): MemorySnapshot = synchronized:
      MemorySnapshot(usedBytes, budgetBytes, allocations.size,
        usedBytes.toDouble / budgetBytes.toDouble)

    def allocationSnapshot(): Map[String, Long] = synchronized:
      allocations.toMap

  final case class BrowserRequest(
      url: String,
      method: String = "GET",
      headers: Map[String, String] = Map.empty
  ):
    require(url.trim.nonEmpty, "URL cannot be blank")

  final case class BrowserResponse(
      status: Int,
      contentType: String,
      contentLength: Long,
      bodyPreview: String
  )

  trait BrowserTransport:
    def execute(request: BrowserRequest): BrowserResponse

  final class UrlPolicy(allowedSchemes: Set[String]):
    private val normalized = allowedSchemes.map(_.toLowerCase)

    def validate(raw: String): Outcome[String] =
      val value = Option(raw).getOrElse("").trim
      if value.isEmpty then Outcome.failure("URL is empty")
      else if value.exists(_.isControl) then
        Outcome.failure("URL contains control characters")
      else
        val separator = value.indexOf(':')
        if separator <= 0 then Outcome.failure("URL must include a scheme")
        else
          val scheme = value.substring(0, separator).toLowerCase
          if normalized.contains(scheme) then Outcome.success(value)
          else Outcome.failure(s"scheme is not allowed: $scheme")

  final case class Tab(
      id: String,
      title: String,
      currentUrl: String,
      createdAt: Instant,
      pinned: Boolean = false
  )

  final class TabManager(limit: Int, clock: Clock = SystemClock):
    require(limit > 0, "tab limit must be positive")
    private val tabs = mutable.LinkedHashMap.empty[String, Tab]
    private var activeId: Option[String] = None

    def open(url: String): Outcome[Tab] = synchronized:
      if tabs.size >= limit then Outcome.failure("tab limit reached")
      else
        val tab = Tab(UUID.randomUUID().toString, "New tab",
          url, clock.now())
        tabs.update(tab.id, tab)
        activeId = Some(tab.id)
        Outcome.success(tab)

    def close(id: String): Boolean = synchronized:
      val removed = tabs.remove(id).isDefined
      if activeId.contains(id) then activeId = tabs.keys.lastOption
      removed

    def active(): Option[Tab] = synchronized:
      activeId.flatMap(tabs.get)

    def activate(id: String): Outcome[Boolean] = synchronized:
      if tabs.contains(id) then
        activeId = Some(id)
        Outcome.success(true)
      else Outcome.failure("tab not found")

    def list(): Vector[Tab] = synchronized:
      tabs.values.toVector

    def size: Int = synchronized:
      tabs.size

  final case class World(
      id: String,
      name: String,
      state: WorldState,
      attributes: Map[String, String],
      createdAt: Instant
  )

  final class Multiverse(clock: Clock = SystemClock):
    private val worlds = mutable.LinkedHashMap.empty[String, World]

    def create(
        name: String,
        attributes: Map[String, String] = Map.empty
    ): Outcome[World] = synchronized:
      if name.trim.isEmpty then Outcome.failure("name required")
      else
        val world = World(UUID.randomUUID().toString, name,
          WorldState.Active, attributes, clock.now())
        worlds.update(world.id, world)
        Outcome.success(world)

    def changeState(id: String, state: WorldState): Outcome[World] =
      synchronized:
        worlds.get(id) match
          case None => Outcome.failure("world not found")
          case Some(current) =>
            val changed = current.copy(state = state)
            worlds.update(id, changed)
            Outcome.success(changed)

    def delete(id: String): Boolean = synchronized:
      worlds.remove(id).isDefined

    def get(id: String): Option[World] = synchronized:
      worlds.get(id)

    def list(): Vector[World] = synchronized:
      worlds.values.toVector.sortBy(_.createdAt)

  final case class Resource(
      id: String,
      kind: ResourceKind,
      uri: String,
      bytes: Long,
      observedAt: Instant
  )

  final class ResourceCatalog(clock: Clock = SystemClock):
    private val resources = mutable.LinkedHashMap.empty[String, Resource]

    def add(
        kind: ResourceKind,
        uri: String,
        bytes: Long
    ): Outcome[Resource] = synchronized:
      if uri.trim.isEmpty then Outcome.failure("URI required")
      else if bytes < 0 then Outcome.failure("bytes cannot be negative")
      else
        val resource = Resource(UUID.randomUUID().toString,
          kind, uri, bytes, clock.now())
        resources.update(resource.id, resource)
        Outcome.success(resource)

    def byKind(kind: ResourceKind): Vector[Resource] = synchronized:
      resources.values.filter(_.kind == kind).toVector

    def totalBytes: Long = synchronized:
      resources.values.map(_.bytes).sum

    def remove(id: String): Boolean = synchronized:
      resources.remove(id).isDefined

  final case class CoreContext(
      config: CoreConfig,
      diagnostics: Diagnostics,
      events: EventBus,
      memory: MemoryLedger,
      tabs: TabManager,
      multiverse: Multiverse,
      resources: ResourceCatalog
  )

  final class Runtime(config: CoreConfig = CoreConfig()):
    private val diagnostics = new Diagnostics()
    diagnostics.setThreshold(LogLevel.Debug)
    private val events = new EventBus(diagnostics = diagnostics)
    private val context = CoreContext(
      config,
      diagnostics,
      events,
      new MemoryLedger(config.memoryBudgetBytes),
      new TabManager(config.maxTabs),
      new Multiverse(),
      new ResourceCatalog()
    )
    val modules = new ModuleRegistry(diagnostics)
    private var started = false

    def coreContext: CoreContext = context

    def start(): Outcome[Boolean] = synchronized:
      if started then Outcome.success(true)
      else
        started = true
        diagnostics.log(LogLevel.Info, "runtime",
          s"$ProductName $Version started")
        events.publish("runtime.started", "runtime",
          Map("version" -> Version))
        Outcome.success(true)

    def close(): Unit = synchronized:
      modules.list().reverse.foreach { info =>
        if info.state == ModuleState.Running then modules.stop(info.id)
      }
      context.memory.releaseAll()
      context.events.publish("runtime.stopped", "runtime")
      context.diagnostics.log(LogLevel.Info, "runtime", "runtime stopped")
      started = false

  final class SampleModule extends CoreModule:
    private var running = false
    override val id = "sample"
    override val description =
      "Demonstration module for lifecycle integration"

    override def start(context: CoreContext): Unit =
      running = true
      context.events.publish("sample.ready", id)

    override def stop(): Unit =
      running = false

    def isRunning: Boolean = running

  def selfCheck(): Outcome[Boolean] =
    val diagnostics = new Diagnostics()
    val events = new EventBus(diagnostics = diagnostics)
    val received = new AtomicLong(0L)
    events.subscribe("check", _ => received.incrementAndGet())
    events.publish("check", "self-check", Map("ok" -> "true"))
    if received.get() != 1L then
      return Outcome.failure("event bus check failed")

    val memory = new MemoryLedger(1024)
    if !memory.reserve("test", 512).isSuccess then
      return Outcome.failure("memory reserve check failed")
    if memory.snapshot().usedBytes != 512 then
      return Outcome.failure("memory accounting check failed")

    val policy = new UrlPolicy(Set("https", "http"))
    if !policy.validate("https://example.invalid").isSuccess then
      return Outcome.failure("URL policy check failed")
    if policy.validate("file:///private/data").isSuccess then
      return Outcome.failure("URL policy accepted a blocked scheme")

    val tabs = new TabManager(2)
    tabs.open("about:blank")
    tabs.open("https://example.invalid")
    if tabs.open("https://third.invalid").isSuccess then
      return Outcome.failure("tab limit check failed")

    Outcome.success(true)

  def main(args: Array[String]): Unit =
    selfCheck() match
      case Outcome(Some(true), _) =>
        val runtime = new Runtime()
        runtime.start()
        val sample = new SampleModule()
        runtime.modules.register(sample)
        runtime.modules.start(sample.id, runtime.coreContext)
        runtime.coreContext.diagnostics.log(LogLevel.Info,
          "demo", "Scala core self-check passed")
        println(s"$ProductName v$Version Scala core ready.")
        println(s"Registered modules: ${runtime.modules.list().size}")
        println(s"Memory budget: ${runtime.coreContext.memory.snapshot().budgetBytes}")
        runtime.close()
      case Outcome(_, message) =>
        System.err.println(s"Self-check failed: $message")

object filenum:
  def main(args: Array[String]): Unit =
    WebMachineXScalaCore.main(args)

/**
 * Extension contract catalog
 * --------------------------
 * These entries document stable integration seams for future modules.
 * Implementations should be registered through ModuleRegistry.
 * configuration: Keep user preferences separate from runtime state.
 * profiles: Use named profiles for independent browser settings.
 * privacy: Private sessions should avoid persistent history writes.
 * tabs: Tab identity must remain stable while a tab is open.
 * navigation: Validate a URL before passing it to a transport.
 * transport: Keep network code behind BrowserTransport.
 * rendering: Rendering engines should consume normalized resources.
 * documents: Document parsing must not execute untrusted content.
 * scripts: Script execution belongs in a sandboxed engine adapter.
 * styles: Style processing should be isolated from document storage.
 * images: Image decoding should enforce size and format limits.
 * fonts: Font loading should use an explicit resource budget.
 * memory: Release allocations when tabs or worlds are removed.
 * events: Publish immutable events instead of sharing mutable state.
 * modules: Modules should tolerate repeated start and stop requests.
 * diagnostics: Logs should avoid secrets, tokens, and private page data.
 * multiverse: Worlds represent isolated workspaces, not OS processes.
 * sync: Synchronization adapters should define conflict policies.
 * bookmarks: Bookmark persistence should be implemented as a store.
 * history: History retention must respect private-mode settings.
 * downloads: Downloads should require explicit destination handling.
 * accessibility: Expose semantic names and keyboard actions in UI adapters.
 * localization: Keep user-facing strings outside core logic.
 * security: Prefer allow-lists and least-privilege interfaces.
 * testing: Test failure paths as well as successful operations.
 */
/*
 * Integration requirement 1: Validate inputs at public boundaries.
 * Integration requirement 2: Return an explicit failure result for rejected operations.
 * Integration requirement 3: Avoid mutable objects in event payloads.
 * Integration requirement 4: Keep timestamps injectable for deterministic tests.
 * Integration requirement 5: Do not log credentials or private browsing content.
 * Integration requirement 6: Document ownership of every allocated resource.
 * Integration requirement 7: Release resources when their owning scope closes.
 * Integration requirement 8: Keep platform-specific code behind interfaces.
 * Integration requirement 9: Make lifecycle operations safe to call more than once.
 * Integration requirement 10: Preserve stable identifiers during an object's lifetime.
 * Integration requirement 11: Prefer immutable snapshots for read operations.
 * Integration requirement 12: Bound collections that can grow from user input.
 * Integration requirement 13: Test empty, invalid, and over-limit values.
 * Integration requirement 14: Keep filesystem access outside the core model.
 * Integration requirement 15: Keep network access outside the core model.
 * Integration requirement 16: Treat remote content as untrusted input.
 * Integration requirement 17: Do not infer permissions from a URL string.
 * Integration requirement 18: Separate policy decisions from transport execution.
 * Integration requirement 19: Keep profile data scoped to its profile identifier.
 * Integration requirement 20: Do not persist private-mode session data.
 * Integration requirement 21: Use clear error messages without exposing secrets.
 * Integration requirement 22: Keep module dependencies explicit.
 * Integration requirement 23: Stop modules in reverse startup order.
 * Integration requirement 24: Record diagnostic context without personal data.
 * Integration requirement 25: Make adapters replaceable in unit tests.
 * Integration requirement 26: Validate inputs at public boundaries.
 * Integration requirement 27: Return an explicit failure result for rejected operations.
 * Integration requirement 28: Avoid mutable objects in event payloads.
 * Integration requirement 29: Keep timestamps injectable for deterministic tests.
 * Integration requirement 30: Do not log credentials or private browsing content.
 * Integration requirement 31: Document ownership of every allocated resource.
 * Integration requirement 32: Release resources when their owning scope closes.
 * Integration requirement 33: Keep platform-specific code behind interfaces.
 * Integration requirement 34: Make lifecycle operations safe to call more than once.
 * Integration requirement 35: Preserve stable identifiers during an object's lifetime.
*/