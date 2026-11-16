-- ============================================================================
-- THE WEB MACHINE X :: FUNCTIONAL KERNEL (syscode.hs)
-- Architecture: Zero-Dependency Pure Functional Subsystem Core
-- Target Environment: GHC (Glasgow Haskell Compiler) on Fedora Linux
-- ============================================================================

module Main where
import System.Environment (getArgs)
import Data.List (intercalate, sortBy)
import Data.Ord (comparing)
import Data.Word (Word64)
import qualified Data.Char as C

-------------------------------------------------------------------------------
-- Section 1: Algebraic Data Types and Core Structures
-------------------------------------------------------------------------------

data SystemStatus 
    = Standby 
    | Initializing 
    | ActiveMilestone Int 
    | VerifiedSecure 
    deriving (Eq, Show)

data SubsystemLayer 
    = BareMetalAssembly 
    | NumericFortran 
    | SystemsCoreC 
    | EngineCoreCpp 
    | FunctionalHaskell 
    | ManagedCSharp 
    | WebFrontend 
    deriving (Eq, Show)

data ModuleRecord = ModuleRecord {
    getModName   :: String,
    getModLayer  :: SubsystemLayer,
    getModLines  :: Int,
    getModActive :: Bool
} deriving (Eq, Show)

data EngineConfig = EngineConfig {
    cfgMilestones      :: Int,
    cfgBaselineLines   :: Int,
    cfgSystemSeed      :: Word64,
    cfgDebugMode       :: Bool
} deriving (Eq, Show)

data FunctionalExpr 
    = Constant Word64
    | AddExpr FunctionalExpr FunctionalExpr
    | MulExpr FunctionalExpr FunctionalExpr
    | MilestoneWeight Int
    deriving (Eq, Show)

-------------------------------------------------------------------------------
-- Section 2: Pure Calculation and Evaluation Logic
-------------------------------------------------------------------------------

evalExpr :: EngineConfig -> FunctionalExpr -> Word64
evalExpr _ (Constant val) = val
evalExpr cfg (AddExpr a b) = evalExpr cfg a + evalExpr cfg b
evalExpr cfg (MulExpr a b) = evalExpr cfg a * evalExpr cfg b
evalExpr _ (MilestoneWeight m) = fromIntegral m * 31337

calculateTotalLines :: [ModuleRecord] -> Int
calculateTotalLines [] = 0
calculateTotalLines (x:xs) = 
    if getModActive x 
        then getModLines x + calculateTotalLines xs 
        else calculateTotalLines xs

evaluateStatusString :: SystemStatus -> String
evaluateStatusString Standby = 
    "[STANDBY] Core subsystem dormant."
evaluateStatusString Initializing = 
    "[INIT] Bootstrapping functional execution pipeline..."
evaluateStatusString (ActiveMilestone m) = 
    "[ACTIVE] Processing milestone #" ++ show m ++ " in polyglot environment."
evaluateStatusString VerifiedSecure = 
    "[SECURE] All subsystem layers verified and synchronized."

computeDeterministicHash :: EngineConfig -> Word64 -> Word64
computeDeterministicHash cfg seed =
    let mCount = fromIntegral (cfgMilestones cfg) :: Word64
        lCount = fromIntegral (cfgBaselineLines cfg) :: Word64
        expr   = evalExpr cfg (MulExpr (Constant seed) (Constant 17))
    in (expr + mCount * 101 + lCount * 17) `mod` 1000000007

-------------------------------------------------------------------------------
-- Section 3: Registry Definition and Sorting Subsystems
-------------------------------------------------------------------------------

getPolyglotRegistry :: [ModuleRecord]
getPolyglotRegistry = 
    [ ModuleRecord "system.asm"   BareMetalAssembly  486   True
    , ModuleRecord "numeric.f90"  NumericFortran     486   True
    , ModuleRecord "sysnum.c"     SystemsCoreC       250   True
    , ModuleRecord "websys.c++"   EngineCoreCpp      300   True
    , ModuleRecord "syscode.hs"   FunctionalHaskell  200   True
    , ModuleRecord "syssharp.cs"  ManagedCSharp      200   True
    , ModuleRecord "index.html"   WebFrontend        11602 True
    , ModuleRecord "script.js"    WebFrontend        272   True
    ]

formatModuleRow :: ModuleRecord -> String
formatModuleRow (ModuleRecord name layer linesCount active) =
    let statusTag = if active then "[READY]" else "[PENDING]"
        layerStr  = show layer
        padding   = take (20 - length layerStr) (repeat ' ')
    in " " ++ statusTag ++ " | " ++ layerStr ++ padding ++ " :: " ++ name ++ " (" ++ show linesCount ++ " lines)"

sortRegistryByLines :: [ModuleRecord] -> [ModuleRecord]
sortRegistryByLines = sortBy (flip (comparing getModLines))

-------------------------------------------------------------------------------
-- Section 4: Telemetry and Report Format Generators
-------------------------------------------------------------------------------

generateHeaderBanner :: IO ()
generateHeaderBanner = do
    putStrLn "=========================================================="
    putStrLn " The Web Machine X v0.1"
    putStrLn "=========================================================="

generateFooterBanner :: Word64 -> Int -> IO ()
generateFooterBanner checksum totalLines = do
    putStrLn "----------------------------------------------------------"
    putStrLn $ " Validated Subsystem Line Sum : " ++ show totalLines
    putStrLn $ " Pure Functional Checksum     : 0x" ++ show checksum
    putStrLn "=========================================================="

-------------------------------------------------------------------------------
-- Section 5: Main Entry Point and Execution Flow
-------------------------------------------------------------------------------

main :: IO ()
main = do
    argsList <- getArgs
    generateHeaderBanner

    let config = EngineConfig {
            cfgMilestones    = 245,
            cfgBaselineLines = 24596,
            cfgSystemSeed    = 0x55AA77,
            cfgDebugMode     = True
        }
    let currentStatus = ActiveMilestone 245

    putStrLn $ evaluateStatusString currentStatus
    putStrLn "----------------------------------------------------------"
    putStrLn " Registered Polyglot Subsystems & Line Allocations:"

    let registry       = getPolyglotRegistry
    let sortedRegistry = sortRegistryByLines registry
    mapM_ (putStrLn . formatModuleRow) sortedRegistry

    let totalCalculated = calculateTotalLines registry
    let checksumValue   = computeDeterministicHash config (cfgSystemSeed config)

    generateFooterBanner checksumValue totalCalculated

    case argsList of
        (targetPath:_) -> do
            putStrLn $ "[EXPORT] Target path registered for synchronization: " ++ targetPath
            writeFile targetPath "=== THE WEB MACHINE X :: HASKELL KERNEL EXPORT ===\n"
            putStrLn "[SUCCESS] Telemetry export written successfully."
        _ -> do
            putStrLn "[INFO] Standalone execution completed without external export."

-- ============================================================================
-- End of syscode.hs :: Milestone 245 Pure Functional Execution Module
-- ============================================================================Target path registered: " ++ target
        _          -> return ()
