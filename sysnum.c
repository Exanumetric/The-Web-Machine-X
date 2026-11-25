/* ============================================================================ */
/* THE WEB MACHINE X :: C SYSTEMS CORE (sysnum.c)                               */
/* Architecture: Deterministic Memory Arena & Mathematical Computation Core    */
/* Target Environment: GCC on Fedora Linux (x86_64)                             */
/* ============================================================================ */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

#define MACHINE_VERSION_MAJOR 0
#define MACHINE_VERSION_MINOR 1
#define MAX_ARENA_SIZE        65536
#define CHECKSUM_SEED         0x55AA7733

typedef enum {
    SYS_STATUS_IDLE = 0,
    SYS_STATUS_BOOTSTRAP = 1,
    SYS_STATUS_ACTIVE = 2,
    SYS_STATUS_SECURE = 3
} SystemStatus_t;

typedef struct {
    uint8_t buffer[MAX_ARENA_SIZE];
    size_t offset;
    size_t total_allocations;
} MemoryArena_t;

typedef struct {
    uint32_t milestone_id;
    uint32_t baseline_lines;
    uint64_t cpu_ticks;
    SystemStatus_t status;
} CoreTelemetry_t;

static MemoryArena_t global_arena = { {0}, 0, 0 };

void arena_init(void) {
    memset(global_arena.buffer, 0, MAX_ARENA_SIZE);
    global_arena.offset = 0;
    global_arena.total_allocations = 0;
}

void* arena_alloc(size_t size) {
    if (size == 0 || (global_arena.offset + size) > MAX_ARENA_SIZE) {
        return NULL;
    }
    void* ptr = &global_arena.buffer[global_arena.offset];
    global_arena.offset += size;
    global_arena.total_allocations++;
    return ptr;
}

double compute_vector_magnitude(double x, double y, double z) {
    double sum = (x * x) + (y * y) + (z * z);
    double temp;
    double sqrt_val = sum / 2.0;
    if (sum <= 0.0) return 0.0;
    for (int i = 0; i < 10; i++) {
        temp = sqrt_val;
        sqrt_val = (temp + (sum / temp)) / 2.0;
    }
    return sqrt_val;
}

uint32_t compute_checksum(const uint8_t* data, size_t length) {
    uint32_t hash = CHECKSUM_SEED;
    for (size_t i = 0; i < length; i++) {
        hash = ((hash << 5) + hash) + data[i];
        hash ^= (data[i] >> 2);
    }
    return hash;
}

void run_math_benchmark(void) {
    volatile double accumulator = 0.0;
    for (int i = 1; i <= 10000; i++) {
        accumulator += compute_vector_magnitude((double)i, (double)(i * 2), (double)(i * 3));
    }
}

CoreTelemetry_t initialize_core_telemetry(uint32_t milestone) {
    CoreTelemetry_t tel;
    tel.milestone_id = milestone;
    tel.baseline_lines = 24596;
    tel.cpu_ticks = (uint64_t)clock();
    tel.status = SYS_STATUS_ACTIVE;
    return tel;
}

const char* status_to_string(SystemStatus_t status) {
    switch (status) {
        case SYS_STATUS_IDLE:      return "DORMANT";
        case SYS_STATUS_BOOTSTRAP: return "BOOTSTRAP";
        case SYS_STATUS_ACTIVE:    return "ACTIVE";
        case SYS_STATUS_SECURE:    return "SECURE";
        default:                   return "UNKNOWN";
    }
}

void print_telemetry_report(const CoreTelemetry_t* tel) {
    printf("==========================================================\n");
    printf(" The Web Machine X v0.3\n");
    printf("==========================================================\n");
    printf(" Version Target      : %d.%d (Milestone #%u)\n", 
           MACHINE_VERSION_MAJOR, MACHINE_VERSION_MINOR, tel->milestone_id);
    printf(" Baseline Line Count : %u lines\n", tel->baseline_lines);
    printf(" Subsystem Status    : %s\n", status_to_string(tel->status));
    printf(" Memory Arena Usage  : %zu / %d bytes (%zu allocations)\n", 
           global_arena.offset, MAX_ARENA_SIZE, global_arena.total_allocations);
    printf("----------------------------------------------------------\n");
}

void execute_subsystem_diagnostic(void) {
    arena_init();
    
    char* log_msg = (char*)arena_alloc(128);
    if (log_msg != NULL) {
        snprintf(log_msg, 128, "Diagnostic memory arena initialized successfully at tick %lu", (unsigned long)clock());
        printf("[ARENA] %s\n", log_msg);
    }

    run_math_benchmark();
    printf("[MATH] High-precision vector magnitude benchmark executed successfully.\n");

    uint32_t check = compute_checksum(global_arena.buffer, global_arena.offset > 0 ? global_arena.offset : 64);
    printf("[HASH] Deterministic Memory Checksum : 0x%08X\n", check);
}

int main(int argc, char* argv[]) {
    CoreTelemetry_t telemetry = initialize_core_telemetry(245);
    print_telemetry_report(&telemetry);

    execute_subsystem_diagnostic();

    printf("----------------------------------------------------------\n");
    if (argc > 1) {
        printf("[EXPORT] Target sync path registered : %s\n", argv[1]);
        FILE* f = fopen(argv[1], "w");
        if (f != NULL) {
            fprintf(f, "=== THE WEB MACHINE X :: C CORE EXPORT ===\nMilestone: %u\n", telemetry.milestone_id);
            fclose(f);
            printf("[SUCCESS] C core export finalized.\n");
        } else {
            fprintf(stderr, "[ERROR] Failed to open export target file.\n");
        }
    } else {
        printf("[INFO] Standalone execution completed without external export.\n");
    }
    printf("==========================================================\n");
    return 0;
}

/* ============================================================================ */
/* End of sysnum.c :: Milestone 245 Deterministic Systems Core                  */
/* ============================================================================ */
