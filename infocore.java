/*
 * The Web Machine X — Java Core
 * File: infocore.java
 * Purpose: A dependency-free Java 17 reference core for configuration,
 * module registration, events, memory accounting, browser abstractions,
 * multiverse workspaces, diagnostics, and safe utility operations.
 *
 * This is an application-layer foundation, not a complete web browser.
 * Browser networking and rendering are represented by interfaces so that
 * platform-specific implementations can be added without coupling the core.
 */

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Consumer;
import java.util.regex.Pattern;

public final class infocore {
    private infocore() {}

    public static final String PRODUCT = "Web Machine X";
    public static final String VERSION = "0.3";
    public static final int DEFAULT_MAX_TABS = 32;
    public static final long DEFAULT_MEMORY_BUDGET = 512L * 1024L * 1024L;

    public enum LogLevel { TRACE, DEBUG, INFO, WARN, ERROR }
    public enum ModuleState { CREATED, STARTING, RUNNING, STOPPING, STOPPED, FAILED }
    public enum WorldState { ACTIVE, PAUSED, ARCHIVED }
    public enum ResourceKind { DOCUMENT, SCRIPT, STYLE, IMAGE, FONT, OTHER }

    public record Result<T>(boolean success, T value, String message) {
        public static <T> Result<T> ok(T value) {
            return new Result<>(true, value, "ok");
        }
        public static <T> Result<T> error(String message) {
            return new Result<>(false, null, Objects.requireNonNull(message));
        }
        public Optional<T> optional() {
            return Optional.ofNullable(value);
        }
    }

    public record LogEntry(Instant time, LogLevel level, String area,
                           String message, Map<String, String> context) {
        public LogEntry {
            time = Objects.requireNonNull(time);
            level = Objects.requireNonNull(level);
            area = Objects.requireNonNullElse(area, "core");
            message = Objects.requireNonNullElse(message, "");
            context = Map.copyOf(context == null ? Map.of() : context);
        }
    }

    public interface Clock {
        Instant now();
    }

    public static final class SystemClock implements Clock {
        @Override public Instant now() { return Instant.now(); }
    }

    public static final class Diagnostics {
        private final Clock clock;
        private final List<LogEntry> entries = new CopyOnWriteArrayList<>();
        private volatile LogLevel threshold = LogLevel.INFO;

        public Diagnostics(Clock clock) {
            this.clock = Objects.requireNonNull(clock);
        }

        public void threshold(LogLevel value) {
            threshold = Objects.requireNonNull(value);
        }

        public void log(LogLevel level, String area, String message) {
            log(level, area, message, Map.of());
        }

        public void log(LogLevel level, String area, String message,
                        Map<String, String> context) {
            if (level.ordinal() < threshold.ordinal()) return;
            entries.add(new LogEntry(clock.now(), level, area, message, context));
        }

        public List<LogEntry> snapshot() {
            return List.copyOf(entries);
        }

        public List<LogEntry> recent(int count) {
            if (count <= 0) return List.of();
            int start = Math.max(0, entries.size() - count);
            return List.copyOf(entries.subList(start, entries.size()));
        }

        public long count(LogLevel level) {
            return entries.stream().filter(e -> e.level() == level).count();
        }

        public void clear() {
            entries.clear();
        }
    }

    public record CoreConfig(String profile, int maxTabs, long memoryBudgetBytes,
                             boolean privateMode, boolean diagnosticsEnabled) {
        public CoreConfig {
            profile = Objects.requireNonNullElse(profile, "default");
            if (profile.isBlank()) throw new IllegalArgumentException("profile is blank");
            if (maxTabs < 1 || maxTabs > 512) {
                throw new IllegalArgumentException("maxTabs must be 1..512");
            }
            if (memoryBudgetBytes < 16L * 1024L * 1024L) {
                throw new IllegalArgumentException("memory budget is too small");
            }
        }

        public static CoreConfig defaults() {
            return new CoreConfig("default", DEFAULT_MAX_TABS,
                    DEFAULT_MEMORY_BUDGET, false, true);
        }

        public CoreConfig withPrivateMode(boolean enabled) {
            return new CoreConfig(profile, maxTabs, memoryBudgetBytes,
                    enabled, diagnosticsEnabled);
        }
    }

    public interface ConfigStore {
        Optional<String> read(String key);
        void write(String key, String value);
        void remove(String key);
    }

    public static final class MemoryConfigStore implements ConfigStore {
        private final Map<String, String> values = new ConcurrentHashMap<>();
        @Override public Optional<String> read(String key) {
            return Optional.ofNullable(values.get(key));
        }
        @Override public void write(String key, String value) {
            values.put(Objects.requireNonNull(key), Objects.requireNonNull(value));
        }
        @Override public void remove(String key) { values.remove(key); }
        public Map<String, String> snapshot() { return Map.copyOf(values); }
    }

    public interface CoreModule {
        String id();
        String description();
        void start(CoreContext context) throws Exception;
        void stop() throws Exception;
    }

    public record ModuleInfo(String id, String description, ModuleState state,
                             Instant changedAt) {}

    public static final class ModuleRegistry {
        private final Map<String, CoreModule> modules = new LinkedHashMap<>();
        private final Map<String, ModuleState> states = new LinkedHashMap<>();
        private final Diagnostics diagnostics;
        private final Clock clock;

        public ModuleRegistry(Diagnostics diagnostics, Clock clock) {
            this.diagnostics = diagnostics;
            this.clock = clock;
        }

        public synchronized Result<Boolean> register(CoreModule module) {
            Objects.requireNonNull(module);
            if (module.id() == null || module.id().isBlank()) {
                return Result.error("module id is required");
            }
            if (modules.containsKey(module.id())) {
                return Result.error("duplicate module: " + module.id());
            }
            modules.put(module.id(), module);
            states.put(module.id(), ModuleState.CREATED);
            diagnostics.log(LogLevel.INFO, "modules", "registered " + module.id());
            return Result.ok(Boolean.TRUE);
        }

        public synchronized Result<Boolean> start(String id, CoreContext context) {
            CoreModule module = modules.get(id);
            if (module == null) return Result.error("unknown module: " + id);
            ModuleState state = states.get(id);
            if (state == ModuleState.RUNNING) return Result.ok(Boolean.TRUE);
            states.put(id, ModuleState.STARTING);
            try {
                module.start(context);
                states.put(id, ModuleState.RUNNING);
                diagnostics.log(LogLevel.INFO, "modules", "started " + id);
                return Result.ok(Boolean.TRUE);
            } catch (Exception exception) {
                states.put(id, ModuleState.FAILED);
                diagnostics.log(LogLevel.ERROR, "modules",
                        "failed to start " + id,
                        Map.of("reason", exception.getMessage() == null
                                ? exception.getClass().getSimpleName()
                                : exception.getMessage()));
                return Result.error("module start failed: " + id);
            }
        }

        public synchronized Result<Boolean> stop(String id) {
            CoreModule module = modules.get(id);
            if (module == null) return Result.error("unknown module: " + id);
            if (states.get(id) == ModuleState.STOPPED) return Result.ok(Boolean.TRUE);
            states.put(id, ModuleState.STOPPING);
            try {
                module.stop();
                states.put(id, ModuleState.STOPPED);
                diagnostics.log(LogLevel.INFO, "modules", "stopped " + id);
                return Result.ok(Boolean.TRUE);
            } catch (Exception exception) {
                states.put(id, ModuleState.FAILED);
                return Result.error("module stop failed: " + id);
            }
        }

        public synchronized List<ModuleInfo> list() {
            List<ModuleInfo> result = new ArrayList<>();
            modules.forEach((id, module) -> result.add(new ModuleInfo(
                    id, module.description(), states.get(id), clock.now())));
            return List.copyOf(result);
        }

        public synchronized Optional<CoreModule> find(String id) {
            return Optional.ofNullable(modules.get(id));
        }
    }

    public record CoreEvent(String type, Instant time, String source,
                            Map<String, Object> payload) {
        public CoreEvent {
            Objects.requireNonNull(type);
            time = Objects.requireNonNull(time);
            source = Objects.requireNonNullElse(source, "unknown");
            payload = Map.copyOf(payload == null ? Map.of() : payload);
        }
    }

    public static final class EventBus {
        private final Map<String, List<Consumer<CoreEvent>>> listeners =
                new ConcurrentHashMap<>();
        private final Clock clock;
        private final Diagnostics diagnostics;

        public EventBus(Clock clock, Diagnostics diagnostics) {
            this.clock = clock;
            this.diagnostics = diagnostics;
        }

        public AutoCloseable subscribe(String type, Consumer<CoreEvent> listener) {
            Objects.requireNonNull(type);
            Objects.requireNonNull(listener);
            listeners.computeIfAbsent(type, ignored -> new CopyOnWriteArrayList<>())
                    .add(listener);
            return () -> listeners.getOrDefault(type, List.of()).remove(listener);
        }

        public void publish(String type, String source, Map<String, Object> payload) {
            CoreEvent event = new CoreEvent(type, clock.now(), source, payload);
            for (Consumer<CoreEvent> listener :
                    listeners.getOrDefault(type, List.of())) {
                try {
                    listener.accept(event);
                } catch (RuntimeException exception) {
                    diagnostics.log(LogLevel.ERROR, "events",
                            "listener failed for " + type);
                }
            }
        }

        public int listenerCount(String type) {
            return listeners.getOrDefault(type, List.of()).size();
        }
    }

    public record MemorySnapshot(long usedBytes, long budgetBytes,
                                 int allocations, double utilization) {}

    public static final class MemoryLedger {
        private final long budgetBytes;
        private final Map<String, Long> allocations = new ConcurrentHashMap<>();
        private final AtomicLong used = new AtomicLong();

        public MemoryLedger(long budgetBytes) {
            if (budgetBytes <= 0) throw new IllegalArgumentException("budget");
            this.budgetBytes = budgetBytes;
        }

        public Result<Boolean> reserve(String owner, long bytes) {
            if (owner == null || owner.isBlank()) return Result.error("owner required");
            if (bytes <= 0) return Result.error("bytes must be positive");
            synchronized (this) {
                long previous = allocations.getOrDefault(owner, 0L);
                long nextTotal = used.get() - previous + bytes;
                if (nextTotal > budgetBytes) return Result.error("memory budget exceeded");
                allocations.put(owner, bytes);
                used.set(nextTotal);
                return Result.ok(Boolean.TRUE);
            }
        }

        public synchronized void release(String owner) {
            Long bytes = allocations.remove(owner);
            if (bytes != null) used.addAndGet(-bytes);
        }

        public synchronized void releaseAll() {
            allocations.clear();
            used.set(0);
        }

        public MemorySnapshot snapshot() {
            long current = used.get();
            return new MemorySnapshot(current, budgetBytes, allocations.size(),
                    (double) current / budgetBytes);
        }

        public Map<String, Long> allocations() {
            return Map.copyOf(allocations);
        }
    }

    public record BrowserRequest(String url, String method,
                                 Map<String, String> headers) {
        public BrowserRequest {
            url = Objects.requireNonNull(url);
            method = Objects.requireNonNullElse(method, "GET").toUpperCase();
            headers = Map.copyOf(headers == null ? Map.of() : headers);
        }
    }

    public record BrowserResponse(int status, String contentType,
                                  long contentLength, String bodyPreview) {}

    public interface BrowserTransport {
        BrowserResponse execute(BrowserRequest request) throws Exception;
    }

    public static final class UrlPolicy {
        private static final Pattern SCHEME =
                Pattern.compile("^[a-zA-Z][a-zA-Z0-9+.-]*:");
        private final Set<String> allowedSchemes;

        public UrlPolicy(Set<String> allowedSchemes) {
            this.allowedSchemes = Set.copyOf(allowedSchemes);
        }

        public Result<String> validate(String raw) {
            if (raw == null || raw.isBlank()) return Result.error("URL is empty");
            String value = raw.trim();
            if (value.chars().anyMatch(Character::isISOControl)) {
                return Result.error("URL contains control characters");
            }
            if (!SCHEME.matcher(value).find()) {
                return Result.error("URL must include a scheme");
            }
            String scheme = value.substring(0, value.indexOf(':')).toLowerCase();
            if (!allowedSchemes.contains(scheme)) {
                return Result.error("scheme is not allowed: " + scheme);
            }
            return Result.ok(value);
        }
    }

    public record Tab(String id, String title, String currentUrl,
                      Instant createdAt, boolean pinned) {}

    public static final class TabManager {
        private final int limit;
        private final Map<String, Tab> tabs = new LinkedHashMap<>();
        private String activeId;

        public TabManager(int limit) {
            if (limit < 1) throw new IllegalArgumentException("limit");
            this.limit = limit;
        }

        public synchronized Result<Tab> open(String url, Clock clock) {
            if (tabs.size() >= limit) return Result.error("tab limit reached");
            String id = UUID.randomUUID().toString();
            Tab tab = new Tab(id, "New tab", url, clock.now(), false);
            tabs.put(id, tab);
            activeId = id;
            return Result.ok(tab);
        }

        public synchronized boolean close(String id) {
            Tab removed = tabs.remove(id);
            if (removed == null) return false;
            if (Objects.equals(activeId, id)) {
                activeId = tabs.keySet().stream().reduce((first, second) -> second)
                        .orElse(null);
            }
            return true;
        }

        public synchronized Optional<Tab> active() {
            return Optional.ofNullable(tabs.get(activeId));
        }

        public synchronized Result<Boolean> activate(String id) {
            if (!tabs.containsKey(id)) return Result.error("tab not found");
            activeId = id;
            return Result.ok(Boolean.TRUE);
        }

        public synchronized List<Tab> list() {
            return List.copyOf(tabs.values());
        }

        public synchronized int size() { return tabs.size(); }
    }

    public record World(String id, String name, WorldState state,
                        Map<String, String> attributes, Instant createdAt) {
        public World {
            attributes = Map.copyOf(attributes == null ? Map.of() : attributes);
        }
    }

    public static final class Multiverse {
        private final Map<String, World> worlds = new LinkedHashMap<>();
        private final Clock clock;

        public Multiverse(Clock clock) { this.clock = clock; }

        public synchronized Result<World> create(String name,
                                                  Map<String, String> attributes) {
            if (name == null || name.isBlank()) return Result.error("name required");
            String id = UUID.randomUUID().toString();
            World world = new World(id, name, WorldState.ACTIVE,
                    attributes, clock.now());
            worlds.put(id, world);
            return Result.ok(world);
        }

        public synchronized Result<World> changeState(String id, WorldState state) {
            World current = worlds.get(id);
            if (current == null) return Result.error("world not found");
            World changed = new World(current.id(), current.name(), state,
                    current.attributes(), current.createdAt());
            worlds.put(id, changed);
            return Result.ok(changed);
        }

        public synchronized boolean delete(String id) {
            return worlds.remove(id) != null;
        }

        public synchronized Optional<World> get(String id) {
            return Optional.ofNullable(worlds.get(id));
        }

        public synchronized List<World> list() {
            return worlds.values().stream()
                    .sorted(Comparator.comparing(World::createdAt))
                    .toList();
        }
    }

    public record Resource(String id, ResourceKind kind, String uri,
                           long bytes, Instant observedAt) {}

    public static final class ResourceCatalog {
        private final Map<String, Resource> resources = new LinkedHashMap<>();
        private final Clock clock;

        public ResourceCatalog(Clock clock) { this.clock = clock; }

        public synchronized Result<Resource> add(ResourceKind kind,
                                                   String uri, long bytes) {
            if (uri == null || uri.isBlank()) return Result.error("URI required");
            if (bytes < 0) return Result.error("bytes cannot be negative");
            String id = UUID.randomUUID().toString();
            Resource resource = new Resource(id, kind, uri, bytes, clock.now());
            resources.put(id, resource);
            return Result.ok(resource);
        }

        public synchronized List<Resource> byKind(ResourceKind kind) {
            return resources.values().stream()
                    .filter(resource -> resource.kind() == kind).toList();
        }

        public synchronized long totalBytes() {
            return resources.values().stream().mapToLong(Resource::bytes).sum();
        }

        public synchronized boolean remove(String id) {
            return resources.remove(id) != null;
        }
    }

    public record CoreContext(CoreConfig config, Diagnostics diagnostics,
                              EventBus events, MemoryLedger memory,
                              TabManager tabs, Multiverse multiverse,
                              ResourceCatalog resources) {}

    public static final class Runtime implements AutoCloseable {
        private final CoreContext context;
        private final ModuleRegistry modules;
        private boolean started;

        public Runtime(CoreConfig config) {
            Clock clock = new SystemClock();
            Diagnostics diagnostics = new Diagnostics(clock);
            diagnostics.threshold(LogLevel.DEBUG);
            EventBus events = new EventBus(clock, diagnostics);
            MemoryLedger memory = new MemoryLedger(config.memoryBudgetBytes());
            TabManager tabs = new TabManager(config.maxTabs());
            Multiverse multiverse = new Multiverse(clock);
            ResourceCatalog resources = new ResourceCatalog(clock);
            context = new CoreContext(config, diagnostics, events, memory,
                    tabs, multiverse, resources);
            modules = new ModuleRegistry(diagnostics, clock);
        }

        public CoreContext context() { return context; }
        public ModuleRegistry modules() { return modules; }

        public synchronized Result<Boolean> start() {
            if (started) return Result.ok(Boolean.TRUE);
            started = true;
            context.diagnostics().log(LogLevel.INFO, "runtime",
                    PRODUCT + " " + VERSION + " started");
            context.events().publish("runtime.started", "runtime",
                    Map.of("version", VERSION));
            return Result.ok(Boolean.TRUE);
        }

        @Override public synchronized void close() {
            List<ModuleInfo> infos = modules.list();
            for (int index = infos.size() - 1; index >= 0; index--) {
                ModuleInfo info = infos.get(index);
                if (info.state() == ModuleState.RUNNING) modules.stop(info.id());
            }
            context.memory().releaseAll();
            context.events().publish("runtime.stopped", "runtime", Map.of());
            context.diagnostics().log(LogLevel.INFO, "runtime", "runtime stopped");
            started = false;
        }
    }

    public static final class SampleModule implements CoreModule {
        private boolean running;
        @Override public String id() { return "sample"; }
        @Override public String description() {
            return "Demonstration module for lifecycle integration";
        }
        @Override public void start(CoreContext context) {
            running = true;
            context.events().publish("sample.ready", id(), Map.of());
        }
        @Override public void stop() { running = false; }
        public boolean isRunning() { return running; }
    }

    public static Result<Boolean> selfCheck() {
        Clock clock = new SystemClock();
        Diagnostics diagnostics = new Diagnostics(clock);
        EventBus events = new EventBus(clock, diagnostics);
        AtomicLong received = new AtomicLong();
        events.subscribe("check", ignored -> received.incrementAndGet());
        events.publish("check", "self-check", Map.of("ok", true));
        if (received.get() != 1) return Result.error("event bus check failed");

        MemoryLedger memory = new MemoryLedger(1024);
        if (!memory.reserve("test", 512).success()) {
            return Result.error("memory reserve check failed");
        }
        if (memory.snapshot().usedBytes() != 512) {
            return Result.error("memory accounting check failed");
        }

        UrlPolicy policy = new UrlPolicy(Set.of("https", "http"));
        if (!policy.validate("https://example.invalid").success()) {
            return Result.error("URL policy check failed");
        }
                if (policy.validate("file:///private/data").success()) {
            return Result.error("URL policy accepted a blocked scheme");
        }

        return Result.ok(Boolean.TRUE);
    }
    public static void main(String[] args) {
        Result<Boolean> result = selfCheck();
        System.out.println(result.success() ? "The Web Machine X v0.3: Self-check passed" : result.message());
    }
}
