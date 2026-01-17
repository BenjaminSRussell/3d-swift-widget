import Metal
import Foundation

/// ShaderBundle: Robust shader library locator for OmniCore.
/// Handles bundle resolution across Main App, Widget Extensions, and Unit Tests.
public final class ShaderBundle {
    
    public static let shared = ShaderBundle()
    
    private var libraries: [MTLLibrary] = []
    
    // Legacy single library support for property access
    public var metalLibrary: MTLLibrary {
        return libraries.first ?? MetalContext.shared.device.makeDefaultLibrary()! 
    }
    
    private init() {
        let device = MetalContext.shared.device
        var loadedLibs: [MTLLibrary] = []
        
        // 1. Search all bundles for pre-compiled Metal libraries
        // This is necessary because we have split targets (OmniCore, OmniGeometry, OmniStochastic)
        // each producing their own bundle with a .metallib.
        
        print("DEBUG: ShaderBundle - Scanning \(Bundle.allBundles.count) bundles for Metal libraries...")
        
        for bundle in Bundle.allBundles {
            // Try standard Bundle.module approach (makeDefaultLibrary(bundle:))
            if let lib = try? device.makeDefaultLibrary(bundle: bundle) {
                print("DEBUG: Loaded default library from bundle: \(bundle.bundlePath)")
                loadedLibs.append(lib)
            } else if let url = bundle.url(forResource: "default", withExtension: "metallib") {
                // Fallback for explicit default.metallib lookup
                if let lib = try? device.makeLibrary(URL: url) {
                    print("DEBUG: Loaded default.metallib from resource in: \(bundle.bundlePath)")
                    loadedLibs.append(lib)
                }
            } else if let url = bundle.url(forResource: "OmniShaders", withExtension: "metallib") {
                 if let lib = try? device.makeLibrary(URL: url) {
                    print("DEBUG: Loaded OmniShaders.metallib from: \(bundle.bundlePath)")
                    loadedLibs.append(lib)
                }
            }
        }
        
        if !loadedLibs.isEmpty {
            self.libraries = loadedLibs
            print("DEBUG: ShaderBundle - Successfully loaded \(loadedLibs.count) Metal libraries.")
            return
        }
        
        // Strategy 2: Runtime Source Compilation (Last Resort)
        // Should only run if NO pre-compiled libraries were found.
        print("DEBUG: No pre-compiled libraries found. Attempting runtime source compilation...")
        let runtimeLibs = Self.compileFromSource(device: device)
        if !runtimeLibs.isEmpty {
            print("DEBUG: Runtime compilation SUCCESS. Loaded \(runtimeLibs.count) libraries.")
            self.libraries = runtimeLibs
            return
        }

        fatalError("Metal Library not found and runtime compilation failed.")
    }
    
    /// Returns a function from the shader library.
    public func makeFunction(name: String) -> MTLFunction? {
        for lib in libraries {
            if let fn = lib.makeFunction(name: name) {
                return fn
            }
        }
        return nil
    }

    private static func compileFromSource(device: MTLDevice) -> [MTLLibrary] {
        var bundlesToCheck = Bundle.allBundles
        #if SWIFT_PACKAGE
        bundlesToCheck.append(Bundle.module)
        #endif
        
        var validLibraries: [MTLLibrary] = []
        var sources: [String: String] = [:]
        
        // 1. Gather all shader sources from all bundles
        for bundle in bundlesToCheck {
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(at: bundle.bundleURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
                continue
            }
            
            for case let url as URL in enumerator {
                if url.pathExtension == "metal" || url.pathExtension == "h" {
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        sources[url.lastPathComponent] = content
                    }
                }
            }
        }
        
        // 2. Helper to resolve includes recursively
        func resolveIncludes(content: String, visited: inout Set<String>) -> String {
            var resolved = ""
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("#include") {
                    // Extract filename: #include "Name.metal" or <Name.metal>
                    let components = trimmed.components(separatedBy: "\"")
                    if components.count >= 2 {
                        let filename = components[1]
                        if filename == "metal_stdlib" {
                            // Keep stdlib include
                            resolved += line + "\n"
                        } else if let includedContent = sources[filename] {
                            if !visited.contains(filename) {
                                visited.insert(filename)
                                // Standardize headers: Strip #pragma once from included files
                                let cleanContent = includedContent.replacingOccurrences(of: "#pragma once", with: "// #pragma once processed")
                                resolved += resolveIncludes(content: cleanContent, visited: &visited) + "\n"
                            }
                        } else {
                            // If we can't find it (e.g. relative path resolution issue), try simple matching
                            // Handle ../Include/OmniShaderTypes.h -> OmniShaderTypes.h
                            let simpleName = URL(fileURLWithPath: filename).lastPathComponent
                             if let includedContent = sources[simpleName] {
                                 if !visited.contains(simpleName) {
                                    visited.insert(simpleName)
                                    let cleanContent = includedContent.replacingOccurrences(of: "#pragma once", with: "// #pragma once processed")
                                    resolved += resolveIncludes(content: cleanContent, visited: &visited) + "\n"
                                 }
                             } else {
                                 print("DEBUG: Warning - Could not resolve include: \(filename)")
                                 resolved += "// Missing include: \(line)\n"
                             }
                        }
                    } else {
                         resolved += line + "\n"
                    }
                } else if trimmed.hasPrefix("#pragma once") {
                    // Skip pragma once in the final recursive assembly to avoid warnings
                    continue
                } else {
                    resolved += line + "\n"
                }
            }
            return resolved
        }
        
        let options = MTLCompileOptions()
        options.fastMathEnabled = true
        options.languageVersion = .version3_0
        
        // 3. Compile each .metal file
        for (filename, content) in sources {
            if filename.hasSuffix(".metal") && filename != "OmniMath.metal" { // OmniMath is usually a header-like shared lib
                
                var visited = Set<String>()
                // Always inject generic types if not explicitly included? 
                // Better to rely on the file's own includes now that we assume we are resolving them.
                // However, our previous logic injected OmniMath.
                
                let expandedSource = resolveIncludes(content: content, visited: &visited)
                
                do {
                    let lib = try device.makeLibrary(source: expandedSource, options: options)
                    validLibraries.append(lib)
                    print("DEBUG: Compiled \(filename)")
                } catch {
                     // Some files like "OmniMath.metal" might not be meant to be compiled standalone if they lack an entry point, 
                     // but here we are compiling everything. 
                     // If it fails, we log it. `Meshlet.metal` should pass now.
                    print("DEBUG: Failed \(filename): \(error.localizedDescription)")
                }
            }
        }
        
        return validLibraries
    }
}
