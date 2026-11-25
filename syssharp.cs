using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace TheWebMachineX
{
    public enum SubsystemLayer
    {
        BareMetalAssembly,
        SystemsCoreC,
        EngineCoreCpp,
        NumericFortran,
        FunctionalHaskell,
        ManagedCSharp,
        WebFrontend
    }

    public sealed class ModuleDescriptor
    {
        public string FileName { get; }
        public SubsystemLayer Layer { get; }
        public string Role { get; }
        public bool IsCompiledArtifact { get; }

        public ModuleDescriptor(string fileName, SubsystemLayer layer, string role, bool isCompiledArtifact)
        {
            FileName = fileName;
            Layer = layer;
            Role = role;
            IsCompiledArtifact = isCompiledArtifact;
        }
    }

    public sealed class ExecutionMetrics
    {
        public int TotalMilestones { get; set; }
        public int BaseCodeLines { get; set; }
        public int ActiveModulesCount { get; set; }
        public long LastSweepTicks { get; set; }
    }

    public sealed class PolyglotOrchestrator
    {
        private readonly List<ModuleDescriptor> _modules;
        private readonly ExecutionMetrics _metrics;
        private readonly string _rootDirectory;

        public PolyglotOrchestrator(string rootDirectory)
        {
            _rootDirectory = string.IsNullOrWhiteSpace(rootDirectory) ? "." : rootDirectory;
            _modules = new List<ModuleDescriptor>();
            _metrics = new ExecutionMetrics
            {
                TotalMilestones = 245,
                BaseCodeLines = 24596,
                ActiveModulesCount = 0,
                LastSweepTicks = 0
            };
            RegisterDefaultArchitecture();
        }

        private void RegisterDefaultArchitecture()
        {
            _modules.Add(new ModuleDescriptor("system.asm", SubsystemLayer.BareMetalAssembly, "x86_64 Low-Level Interrupts", true));
            _modules.Add(new ModuleDescriptor("numeric.f90", SubsystemLayer.NumericFortran, "Matrix & Floating-Point Compute", true));
            _modules.Add(new ModuleDescriptor("sysnum.c", SubsystemLayer.SystemsCoreC, "Deterministic Memory & Math Core", true));
            _modules.Add(new ModuleDescriptor("websys.c++", SubsystemLayer.EngineCoreCpp, "Object-Oriented Web Engine Bridge", true));
            _modules.Add(new ModuleDescriptor("syscode.hs", SubsystemLayer.FunctionalHaskell, "Pure Functional State Logic", true));
            _modules.Add(new ModuleDescriptor("syssharp.cs", SubsystemLayer.ManagedCSharp, "Managed Runtime & Telemetry Hub", true));
            _modules.Add(new ModuleDescriptor("index.html", SubsystemLayer.WebFrontend, "Core Document Structure", false));
            _modules.Add(new ModuleDescriptor("script.js", SubsystemLayer.WebFrontend, "Vanilla Client Controller", false));
        }

        public void RegisterCustomModule(string fileName, SubsystemLayer layer, string role, bool compiled)
        {
            if (string.IsNullOrWhiteSpace(fileName))
            {
                throw new ArgumentException("Module filename cannot be empty.");
            }
            _modules.Add(new ModuleDescriptor(fileName, layer, role, compiled));
        }

        public Dictionary<string, bool> AuditWorkspaceFiles()
        {
            var statusMap = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
            int foundCount = 0;

            foreach (var module in _modules)
            {
                string fullPath = Path.Combine(_rootDirectory, module.FileName);
                bool exists = File.Exists(fullPath);
                statusMap[module.FileName] = exists;
                if (exists)
                {
                    foundCount++;
                }
            }

            _metrics.ActiveModulesCount = foundCount;
            return statusMap;
        }

        public string BuildTelemetryReport()
        {
            var timer = Stopwatch.StartNew();
            var audit = AuditWorkspaceFiles();
            var report = new StringBuilder();

            report.AppendLine("==========================================================");
            report.AppendLine(" The Web Machine X v0.3");
            report.AppendLine("==========================================================");
            report.AppendLine($" Architecture Target : x86_64 Native / Zero-Dependency");
            report.AppendLine($" Milestone Counter   : {_metrics.TotalMilestones}+");
            report.AppendLine($" Baseline Codebase   : {_metrics.BaseCodeLines} lines");
            report.AppendLine($" Detected Modules    : {_metrics.ActiveModulesCount} / {_modules.Count}");
            report.AppendLine("----------------------------------------------------------");

            foreach (var module in _modules)
            {
                bool present = audit.ContainsKey(module.FileName) && audit[module.FileName];
                string stateTag = present ? "[READY]" : "[PENDING]";
                string typeTag = module.IsCompiledArtifact ? "BIN/SRC" : "ASSET  ";
                report.AppendLine($" {stateTag,-9} | {typeTag} | {module.FileName,-14} | {module.Role}");
            }

            timer.Stop();
            _metrics.LastSweepTicks = timer.ElapsedTicks;

            report.AppendLine("----------------------------------------------------------");
            report.AppendLine($" Sweep Execution Time: {_metrics.LastSweepTicks} CPU ticks");
            report.AppendLine("==========================================================");
            return report.ToString();
        }

        public int ComputeParityChecksum(int seed)
        {
            int accumulator = seed ^ _metrics.TotalMilestones;
            foreach (var module in _modules)
            {
                for (int i = 0; i < module.FileName.Length; i++)
                {
                    accumulator = ((accumulator << 5) + accumulator) ^ module.FileName[i];
                }
            }
            return accumulator & 0x7FFFFFFF;
        }
    }

    public static class Program
    {
        public static int Main(string[] args)
        {
            string targetDir = args.Length > 0 ? args[0] : Directory.GetCurrentDirectory();
            var orchestrator = new PolyglotOrchestrator(targetDir);

            string telemetry = orchestrator.BuildTelemetryReport();
            Console.WriteLine(telemetry);

            int checksum = orchestrator.ComputeParityChecksum(24596);
            Console.WriteLine($"System Integrity Parity Hash : 0x{checksum:X8}");

            if (args.Length > 1 && args[1].Equals("--strict", StringComparison.OrdinalIgnoreCase))
            {
                var audit = orchestrator.AuditWorkspaceFiles();
                foreach (var entry in audit)
                {
                    if (!entry.Value)
                    {
                        Console.Error.WriteLine($"[ERROR] Missing required polyglot module: {entry.Key}");
                        return 1;
                    }
                }
            }

            return 0;
        }
    }
}
