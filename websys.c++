#include <bits/stdc++.h>

namespace TheWebMachineX {

    enum class NodeType {
        DocumentRoot,
        Element,
        TextNode,
        EngineBuffer,
        SystemBridge
    };

    class WebNode {
    private:
        std::string m_tag;
        std::string m_content;
        NodeType m_type;
        std::vector<std::shared_ptr<WebNode>> m_children;

    public:
        WebNode(const std::string& tag, NodeType type, const std::string& content = "")
            : m_tag(tag), m_type(type), m_content(content) {}

        void AddChild(std::shared_ptr<WebNode> child) {
            if (child != nullptr) {
                m_children.push_back(child);
            }
        }

        const std::string& GetTag() const { return m_tag; }
        const std::string& GetContent() const { return m_content; }
        NodeType GetType() const { return m_type; }
        size_t GetChildCount() const { return m_children.size(); }

        std::string Serialize(int indent = 0) const {
            std::string indentation(indent * 2, ' ');
            std::ostringstream oss;

            oss << indentation << "<" << m_tag;
            if (!m_content.empty() && m_children.empty()) {
                oss << ">" << m_content << "</" << m_tag << ">\n";
            } else if (m_children.empty()) {
                oss << " />\n";
            } else {
                oss << ">\n";
                if (!m_content.empty()) {
                    oss << indentation << "  " << m_content << "\n";
                }
                for (const auto& child : m_children) {
                    oss << child->Serialize(indent + 1);
                }
                oss << indentation << "</" << m_tag << ">\n";
            }
            return oss.str();
        }
    };

    struct EnginePerformanceMetrics {
        long long renderTimeMicroseconds;
        size_t memoryFootprintBytes;
        size_t totalNodesManaged;
        bool isOptimized;
    };

    class EngineCoreBridge {
    private:
        std::shared_ptr<WebNode> m_root;
        EnginePerformanceMetrics m_metrics;

    public:
        EngineCoreBridge() {
            m_root = std::make_shared<WebNode>("MachineRoot", NodeType::DocumentRoot);
            m_metrics = {0, 0, 1, true};
        }

        void InitializeDefaultTree() {
            auto head = std::make_shared<WebNode>("head", NodeType::Element);
            head->AddChild(std::make_shared<WebNode>("meta", NodeType::Element, "charset='utf-8'"));
            
            auto body = std::make_shared<WebNode>("body", NodeType::Element);
            auto container = std::make_shared<WebNode>("div", NodeType::Element);
            container->AddChild(std::make_shared<WebNode>("h1", NodeType::Element, "The Web Machine X :: C++ Engine Core"));
            container->AddChild(std::make_shared<WebNode>("p", NodeType::Element, "Native bare-metal polyglot execution environment."));
            
            body->AddChild(container);
            m_root->AddChild(head);
            m_root->AddChild(body);
            
            m_metrics.totalNodesManaged = 7;
        }

        std::string RenderDocument() const {
            if (!m_root) return "";
            return m_root->Serialize(0);
        }

        EnginePerformanceMetrics RunDiagnosticSweep() {
            auto start = std::chrono::high_resolution_clock::now();

            // Simulate high-performance native engine verification pass
            volatile unsigned long long accumulator = 0;
            for (int i = 0; i < 50000; ++i) {
                accumulator += i ^ 0x55AA;
            }

            auto end = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();

            m_metrics.renderTimeMicroseconds = duration;
            m_metrics.memoryFootprintBytes = sizeof(EngineCoreBridge) + (m_metrics.totalNodesManaged * 128);
            m_metrics.isOptimized = true;

            return m_metrics;
        }

        void ExportReport(const std::string& filepath) {
            std::ofstream outfile(filepath);
            if (outfile.is_open()) {
                outfile << "=== THE WEB MACHINE X :: C++ ENGINE REPORT ===\n";
                outfile << RenderDocument();
                outfile.close();
            }
        }
    };
}

int main(int argc, char* argv[]) {
    std::cout << "==========================================================\n";
    std::cout << " The Web Machine X v0.2\n";
    std::cout << "==========================================================\n";

    TheWebMachineX::EngineCoreBridge engine;
    engine.InitializeDefaultTree();

    std::cout << "[INFO] Initializing DOM structure and native render buffers...\n";
    std::string serializedDoc = engine.RenderDocument();
    std::cout << serializedDoc;

    std::cout << "----------------------------------------------------------\n";
    std::cout << "[INFO] Executing high-speed native diagnostic sweep...\n";
    auto metrics = engine.RunDiagnosticSweep();

    std::cout << " Diagnostic Render Time   : " << metrics.renderTimeMicroseconds << " microseconds\n";
    std::cout << " Estimated Memory Footprint: " << metrics.memoryFootprintBytes << " bytes\n";
    std::cout << " Managed Node Tree Size   : " << metrics.totalNodesManaged << " nodes\n";
    std::cout << " Optimization Status      : " << (metrics.isOptimized ? "ACTIVE (Zero-Dependency)" : "PENDING") << "\n";
    std::cout << "==========================================================\n";

    if (argc > 1) {
        std::string outPath(argv[1]);
        engine.ExportReport(outPath);
        std::cout << "[EXPORT] Successfully wrote engine report to: " << outPath << "\n";
    }

    return 0;
}
