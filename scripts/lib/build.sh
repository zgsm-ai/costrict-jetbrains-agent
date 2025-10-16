#!/bin/bash

# Build-specific utility functions
# This file provides functions for building VSCode extensions and IDEA plugins

# Source common utilities (common.sh should be in the same directory)
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/common.sh"

# Build configuration
readonly DEFAULT_BUILD_MODE="release"
readonly VSCODE_BRANCH="develop"
readonly IDEA_DIR="jetbrains_plugin"
readonly TEMP_PREFIX="build_temp_"

# Build modes
readonly BUILD_MODE_RELEASE="release"
readonly BUILD_MODE_DEBUG="debug"

# Global build variables
BUILD_MODE="$DEFAULT_BUILD_MODE"
VSIX_FILE=""
SKIP_VSCODE_BUILD=false
SKIP_BASE_BUILD=false
SKIP_IDEA_BUILD=false
SKIP_NODEJS_PREPARE=false

# Node.js configuration
readonly NODEJS_VERSION="20.6.0"
BUILTIN_NODEJS_DIR=""  # Will be set in init_build_env()
readonly NODEJS_DOWNLOAD_BASE_URL="https://nodejs.org/dist/v${NODEJS_VERSION}"

# Node.js platform mappings
declare -A NODEJS_PLATFORMS=(
    ["windows-x64"]="node-v${NODEJS_VERSION}-win-x64.zip"
    # ["macos-x64"]="node-v${NODEJS_VERSION}-darwin-x64.tar.gz"
    # ["macos-arm64"]="node-v${NODEJS_VERSION}-darwin-arm64.tar.gz"
    # ["linux-x64"]="node-v${NODEJS_VERSION}-linux-x64.tar.xz"
)

# Initialize build environment
init_build_env() {
    log_step "Initializing build environment..."
    
    # Set build paths
    export BUILD_TEMP_DIR="$(mktemp -d -t ${TEMP_PREFIX}XXXXXX)"
    export PLUGIN_BUILD_DIR="$PROJECT_ROOT/$PLUGIN_SUBMODULE_PATH"
    export BASE_BUILD_DIR="$PROJECT_ROOT/$EXTENSION_HOST_DIR"
    export IDEA_BUILD_DIR="$PROJECT_ROOT/$IDEA_DIR"
    export VSCODE_PLUGIN_NAME="${VSCODE_PLUGIN_NAME:-costrict}"
    export VSCODE_PLUGIN_TARGET_DIR="$IDEA_BUILD_DIR/plugins/${VSCODE_PLUGIN_NAME}"
    export BUILTIN_NODEJS_DIR="$IDEA_BUILD_DIR/src/main/resources/builtin-nodejs"
    
    # Validate build tools
    validate_build_tools
    
    log_debug "Build temp directory: $BUILD_TEMP_DIR"
    log_debug "Plugin build directory: $PLUGIN_BUILD_DIR"
    log_debug "Base build directory: $BASE_BUILD_DIR"
    log_debug "IDEA build directory: $IDEA_BUILD_DIR"
    
    log_success "Build environment initialized"
}

# Validate build tools
validate_build_tools() {
    log_step "Validating build tools..."
    
    local required_tools=("git" "node" "npm" "unzip")
    
    # Add platform-specific tools
    if command_exists "pnpm"; then
        log_debug "Found pnpm package manager"
    else
        log_warn "pnpm not found, will use npm"
    fi
    
    # Check for Gradle (for IDEA plugin)
    if command_exists "gradle" || [[ -f "$IDEA_BUILD_DIR/gradlew" ]]; then
        log_debug "Found Gradle build tool"
    else
        log_warn "Gradle not found, IDEA plugin build may fail"
    fi
    
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            die "Required build tool not found: $tool"
        fi
        log_debug "Found build tool: $tool"
    done
    
    log_success "Build tools validation passed"
}

# Initialize git submodules
init_submodules() {
    log_step "Initializing git submodules..."
    
    if [[ ! -d "$PLUGIN_BUILD_DIR" ]] || [[ ! "$(ls -A "$PLUGIN_BUILD_DIR" 2>/dev/null)" ]]; then
        log_info "VSCode submodule not found or empty, initializing..."
        
        cd "$PROJECT_ROOT"
        execute_cmd "git submodule init" "git submodule init"
        execute_cmd "git submodule update" "git submodule update"
        
        log_info "Switching to $VSCODE_BRANCH branch..."
        cd "$PLUGIN_BUILD_DIR"
        execute_cmd "git checkout $VSCODE_BRANCH" "git checkout $VSCODE_BRANCH"
        
        log_success "Git submodules initialized"
    else
        log_info "VSCode submodule already exists, skipping initialization"
    fi
}

# Apply patches to VSCode
apply_vscode_patches() {
    local patch_file="$1"
    
    if [[ -z "$patch_file" ]] || [[ ! -f "$patch_file" ]]; then
        log_warn "No patch file specified or file not found: $patch_file"
        return 0
    fi
    
    log_step "Applying VSCode patches..."
    
    cd "$PLUGIN_BUILD_DIR"
    
    # Check if patch is already applied
    if git apply --check "$patch_file" 2>/dev/null; then
        execute_cmd "git apply '$patch_file'" "patch application"
        log_success "Patch applied successfully"
    else
        log_warn "Patch cannot be applied (may already be applied or conflicts exist)"
    fi
}

# Revert VSCode changes
revert_vscode_changes() {
    log_step "Reverting VSCode changes..."
    
    cd "$PLUGIN_BUILD_DIR"
    execute_cmd "git reset --hard" "git reset"
    execute_cmd "git clean -fd" "git clean"
    
    log_success "VSCode changes reverted"
}

# Build VSCode extension
build_vscode_extension() {
    if [[ "$SKIP_VSCODE_BUILD" == "true" ]]; then
        log_info "Skipping VSCode extension build"
        return 0
    fi
    
    log_step "Building VSCode extension..."
    
    cd "$PLUGIN_BUILD_DIR"
    
    # Install dependencies
    local pkg_manager="npm"
    if command_exists "pnpm" && [[ -f "pnpm-lock.yaml" ]]; then
        pkg_manager="pnpm"
    fi
    
    log_info "Installing dependencies with $pkg_manager..."
    execute_cmd "$pkg_manager install" "dependency installation"
    
    # Apply Windows compatibility fix if needed
    apply_windows_compatibility_fix
    
    # Build based on mode
    if [[ "$BUILD_MODE" == "$BUILD_MODE_DEBUG" ]]; then
        log_info "Building in debug mode..."
        export USE_DEBUG_BUILD="true"
        execute_cmd "$pkg_manager run vsix" "VSIX build"
        execute_cmd "$pkg_manager run bundle" "bundle build"
    else
        log_info "Building in release mode..."
        execute_cmd "$pkg_manager run vsix" "VSIX build"
    fi
    
    # Find the generated VSIX file
    VSIX_FILE=$(get_latest_file "$PLUGIN_BUILD_DIR/bin" "*.vsix")
    if [[ -z "$VSIX_FILE" ]]; then
        die "VSIX file not found after build"
    fi
    
    log_success "VSCode extension built: $VSIX_FILE"
}

# Apply Windows compatibility fix
apply_windows_compatibility_fix() {
    local windows_release_file="$PLUGIN_BUILD_DIR/node_modules/.pnpm/windows-release@6.1.0/node_modules/windows-release/index.js"
    
    if [[ -f "$windows_release_file" ]]; then
        log_debug "Applying Windows compatibility fix..."
        
        # Use perl for cross-platform compatibility
        if command_exists "perl"; then
            perl -i -pe "s/execaSync\\('wmic', \\['os', 'get', 'Caption'\\]\\)\\.stdout \\|\\| ''/''/g" "$windows_release_file"
            perl -i -pe "s/execaSync\\('powershell', \\['\\(Get-CimInstance -ClassName Win32_OperatingSystem\\)\\.caption'\\]\\)\\.stdout \\|\\| ''/''/g" "$windows_release_file"
            log_debug "Windows compatibility fix applied"
        else
            log_warn "perl not found, skipping Windows compatibility fix"
        fi
    fi
}

# Extract VSIX file
extract_vsix() {
    local vsix_file="$1"
    local extract_dir="$2"
    
    if [[ -z "$vsix_file" ]] || [[ ! -f "$vsix_file" ]]; then
        die "VSIX file not found: $vsix_file"
    fi
    
    log_step "Extracting VSIX file..."
    
    ensure_dir "$extract_dir"
    execute_cmd "unzip -q '$vsix_file' -d '$extract_dir'" "VSIX extraction"
    
    log_success "VSIX extracted to: $extract_dir"
}

# Copy VSIX contents to target directory
copy_vscode_extension() {
    local vsix_file="${1:-$VSIX_FILE}"
    local target_dir="${2:-$VSCODE_PLUGIN_TARGET_DIR}"
    
    if [[ -z "$vsix_file" ]]; then
        die "No VSIX file specified"
    fi
    
    log_step "Copying VSCode extension files..."
    
    # Clean target directory
    remove_dir "$target_dir"
    ensure_dir "$target_dir"
    
    # Extract VSIX to temp directory
    local temp_extract_dir="$BUILD_TEMP_DIR/vsix_extract"
    extract_vsix "$vsix_file" "$temp_extract_dir"
    
    # Copy extension files
    copy_files "$temp_extract_dir/extension" "$target_dir/" "VSCode extension files"
    
    log_success "VSCode extension files copied"
}

# Copy debug resources (for debug builds)
copy_debug_resources() {
    if [[ "$BUILD_MODE" != "$BUILD_MODE_DEBUG" ]]; then
        return 0
    fi
    
    log_step "Copying debug resources..."
    
    local debug_res_dir="$PROJECT_ROOT/debug-resources"
    local vscode_plugin_debug_dir="$debug_res_dir/${VSCODE_PLUGIN_NAME}"
    
    # Clean debug resources
    remove_dir "$debug_res_dir"
    ensure_dir "$vscode_plugin_debug_dir"
    
    cd "$PLUGIN_BUILD_DIR"
    
    # Copy various debug resources
    copy_files "src/dist/i18n" "$vscode_plugin_debug_dir/dist/" "i18n files"
    copy_files "src/dist/extension.js" "$vscode_plugin_debug_dir/dist/" "extension.js"
    copy_files "src/dist/extension.js.map" "$vscode_plugin_debug_dir/dist/" "extension.js.map"
    
    # Copy WASM files
    find "$PLUGIN_BUILD_DIR/src/dist" -maxdepth 1 -name "*.wasm" -exec cp {} "$vscode_plugin_debug_dir/dist/" \;
    
    # Copy assets and audio
    copy_files "src/assets" "$vscode_plugin_debug_dir/" "assets"
    copy_files "src/webview-ui/audio" "$vscode_plugin_debug_dir/" "audio files"
    
    # Copy webview build
    copy_files "src/webview-ui/build" "$vscode_plugin_debug_dir/webview-ui/" "webview build"
    
    # Copy theme files
    ensure_dir "$vscode_plugin_debug_dir/src/integrations/theme/default-themes"
    copy_files "src/integrations/theme/default-themes" "$vscode_plugin_debug_dir/src/integrations/theme/" "default themes"
    
    # Copy IDEA themes if they exist
    local idea_themes_dir="$IDEA_BUILD_DIR/src/main/resources/themes"
    if [[ -d "$idea_themes_dir" ]]; then
        copy_files "$idea_themes_dir/*" "$vscode_plugin_debug_dir/src/integrations/theme/default-themes/" "IDEA themes"
    fi
    
    # Copy JSON files (excluding specific ones)
    for json_file in "$PLUGIN_BUILD_DIR"/*.json; do
        local filename=$(basename "$json_file")
        if [[ "$filename" != "package-lock.json" && "$filename" != "tsconfig.json" ]]; then
            copy_files "$json_file" "$vscode_plugin_debug_dir/" "$filename"
        fi
    done
    
    # Remove type field from package.json for CommonJS compatibility
    local debug_package_json="$vscode_plugin_debug_dir/package.json"
    if [[ -f "$debug_package_json" ]]; then
        node -e "
            const fs = require('fs');
            const pkgPath = process.argv[1];
            const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
            delete pkg.type;
            fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2));
            console.log('Removed type field from debug package.json for CommonJS compatibility');
        " "$debug_package_json"
    fi
    
    log_success "Debug resources copied"
}

# Build base extension
build_extension_host() {
    if [[ "$SKIP_BASE_BUILD" == "true" ]]; then
        log_info "Skipping Extension host build"
        return 0
    fi
    
    log_step "Building Extension host..."
    
    cd "$BASE_BUILD_DIR"
    
    # Clean previous build
    remove_dir "dist"
    
    # Build extension
    if [[ "$BUILD_MODE" == "$BUILD_MODE_DEBUG" ]]; then
        execute_cmd "npm run build" "Extension host build (debug)"
    else
        execute_cmd "npm run build:extension" "Extension host build (release)"
    fi
    
    # Generate production dependencies list
    execute_cmd "npm ls --prod --depth=10 --parseable > '$IDEA_BUILD_DIR/prodDep.txt'" "production dependencies list"
    
    log_success "Base extension built"
}

# Copy base extension for debug
copy_base_debug_resources() {
    if [[ "$BUILD_MODE" != "$BUILD_MODE_DEBUG" ]]; then
        return 0
    fi
    
    log_step "Copying base debug resources..."
    
    local debug_res_dir="$PROJECT_ROOT/debug-resources"
    local runtime_dir="$debug_res_dir/runtime"
    local node_modules_dir="$debug_res_dir/node_modules"
    
    ensure_dir "$runtime_dir"
    ensure_dir "$node_modules_dir"
    
    # Copy node_modules
    copy_files "$BASE_BUILD_DIR/node_modules/*" "$node_modules_dir/" "base node_modules"
    
    # Copy package.json and dist
    copy_files "$BASE_BUILD_DIR/package.json" "$runtime_dir/" "base package.json"
    copy_files "$BASE_BUILD_DIR/dist/*" "$runtime_dir/" "base dist files"
    
    log_success "Base debug resources copied"
}

# Download Node.js binary for a specific platform
download_nodejs_binary() {
    local platform="$1"
    local filename="${NODEJS_PLATFORMS[$platform]}"
    local url="$NODEJS_DOWNLOAD_BASE_URL/$filename"
    local target_dir="$BUILTIN_NODEJS_DIR/$platform"
    local target_file="$target_dir/$filename"

    # Skip if already exists and valid
    if [[ -f "$target_file" ]]; then
        local file_size=$(stat -f%z "$target_file" 2>/dev/null || stat -c%s "$target_file" 2>/dev/null || echo "0")
        local min_size=25000000  # 25MB (Windows zip is typically ~28MB)

        if [[ "$file_size" -gt "$min_size" ]]; then
            log_debug "Node.js binary already exists for $platform (${file_size} bytes)"
            return 0
        else
            log_warn "Existing file is too small, re-downloading..."
            rm -f "$target_file"
        fi
    fi

    log_info "Downloading Node.js $NODEJS_VERSION for $platform..."

    ensure_dir "$target_dir"

    # Download with progress
    if command_exists "curl"; then
        execute_cmd "curl -L --progress-bar -o '$target_file' '$url'" "download Node.js $platform"
    elif command_exists "wget"; then
        execute_cmd "wget --show-progress -O '$target_file' '$url'" "download Node.js $platform"
    else
        die "Neither curl nor wget found for downloading Node.js"
    fi

    # Verify download
    local file_size=$(stat -f%z "$target_file" 2>/dev/null || stat -c%s "$target_file" 2>/dev/null || echo "0")
    local min_size=25000000  # 25MB (Windows zip is typically ~28MB)

    if [[ "$file_size" -lt "$min_size" ]]; then
        remove_file "$target_file"
        die "Downloaded Node.js binary appears corrupted for $platform (size: $file_size bytes)"
    fi

    log_success "Downloaded Node.js for $platform ($(( file_size / 1024 / 1024 ))MB)"
}

# Download all Node.js binaries
download_all_nodejs_binaries() {
    log_step "Downloading Node.js binaries for all platforms..."

    for platform in "${!NODEJS_PLATFORMS[@]}"; do
        download_nodejs_binary "$platform"
    done

    log_success "All Node.js binaries downloaded"
}

# Generate Node.js configuration file
generate_nodejs_config() {
    log_step "Generating Node.js configuration..."

    local config_file="$BUILTIN_NODEJS_DIR/config.json"

    # Create JSON config using heredoc
    cat > "$config_file" << EOF
{
  "version": "$NODEJS_VERSION",
  "platforms": {
    "windows-x64": {
      "file": "node-v$NODEJS_VERSION-win-x64.zip",
      "extractPath": "node-v$NODEJS_VERSION-win-x64/",
      "executable": "node.exe"
    },
    "macos-x64": {
      "file": "node-v$NODEJS_VERSION-darwin-x64.tar.gz",
      "extractPath": "node-v$NODEJS_VERSION-darwin-x64/bin/",
      "executable": "node"
    },
    "macos-arm64": {
      "file": "node-v$NODEJS_VERSION-darwin-arm64.tar.gz",
      "extractPath": "node-v$NODEJS_VERSION-darwin-arm64/bin/",
      "executable": "node"
    },
    "linux-x64": {
      "file": "node-v$NODEJS_VERSION-linux-x64.tar.xz",
      "extractPath": "node-v$NODEJS_VERSION-linux-x64/bin/",
      "executable": "node"
    }
  }
}
EOF

    if [[ ! -f "$config_file" ]]; then
        die "Failed to generate Node.js configuration file"
    fi

    log_success "Node.js configuration generated: $config_file"
}

# Prepare builtin Node.js before build (places files in src/main/resources)
prepare_builtin_nodejs_prebuild() {
    if [[ "$SKIP_NODEJS_PREPARE" == "true" ]]; then
        log_info "Skipping Node.js pre-build preparation (SKIP_NODEJS_PREPARE=true)"
        return 0
    fi

    log_step "Preparing builtin Node.js $NODEJS_VERSION for plugin resources..."

    # Use the standard BUILTIN_NODEJS_DIR (src/main/resources/builtin-nodejs)
    ensure_dir "$BUILTIN_NODEJS_DIR"

    # Download binaries
    download_all_nodejs_binaries

    # Generate config
    generate_nodejs_config

    log_success "Builtin Node.js prepared in resources directory: $BUILTIN_NODEJS_DIR"
    
    # Copy asset files (setup scripts) to resources directory
    local asset_target_dir="$IDEA_BUILD_DIR/src/main/resources/scripts"
    copy_asset_files "$asset_target_dir"
}

# Copy asset files (setup scripts) to target directory
# Used by prepare_builtin_nodejs_prebuild to copy to resources directory
copy_asset_files() {
    local target_dir="$1"
    local asset_dir="$PROJECT_ROOT/scripts/asset"
    
    log_step "Copying asset files (setup scripts)..."
    log_debug "Asset directory: $asset_dir"
    log_debug "Target directory: $target_dir"
    
    if [[ ! -d "$asset_dir" ]]; then
        log_warn "Asset directory not found: $asset_dir"
        return 0
    fi
    
    # Ensure target directory exists
    ensure_dir "$target_dir"
    
    # Copy all files from asset directory
    for file in "$asset_dir"/*; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            log_debug "Copying: $filename"
            copy_files "$file" "$target_dir/$filename" "$filename"
        fi
    done
    
    # Make shell scripts executable
    if [[ -f "$target_dir/setup-node.sh" ]]; then
        chmod +x "$target_dir/setup-node.sh"
        log_debug "Made setup-node.sh executable"
    fi
    if [[ -f "$target_dir/setup-node.bat" ]]; then
        chmod +x "$target_dir/setup-node.bat"
        log_debug "Made setup-node.bat executable"
    fi
    
    log_success "Asset files copied to: $target_dir"
}

# Clean IDEA resources after build
# This removes temporary build artifacts from resources directory
clean_idea_resources_postbuild() {
    log_step "Cleaning IDEA temporary resources after build..."
    
    local builtin_nodejs_dir="$IDEA_BUILD_DIR/src/main/resources/builtin-nodejs"
    local scripts_dir="$IDEA_BUILD_DIR/src/main/resources/scripts"
    
    # Remove builtin-nodejs directory
    if [[ -d "$builtin_nodejs_dir" ]]; then
        log_info "Removing builtin-nodejs directory..."
        remove_dir "$builtin_nodejs_dir"
        log_debug "Removed: $builtin_nodejs_dir"
    fi
    
    # Remove scripts directory
    if [[ -d "$scripts_dir" ]]; then
        log_info "Removing scripts directory..."
        remove_dir "$scripts_dir"
        log_debug "Removed: $scripts_dir"
    fi
    
    log_success "IDEA temporary resources cleaned"
}

# Build IDEA plugin
build_idea_plugin() {
    if [[ "$SKIP_IDEA_BUILD" == "true" ]]; then
        log_info "Skipping IDEA plugin build"
        return 0
    fi
    
    log_step "Building IDEA plugin..."
    
    cd "$IDEA_BUILD_DIR"
    
    # Check for Gradle build files
    if [[ ! -f "build.gradle" && ! -f "build.gradle.kts" ]]; then
        die "No Gradle build file found in IDEA directory"
    fi
    
    # Prepare builtin Node.js before building (so it gets packaged into the plugin)
    prepare_builtin_nodejs_prebuild
    
    # Use gradlew if available, otherwise use system gradle
    local gradle_cmd="gradle"
    if [[ -f "./gradlew" ]]; then
        gradle_cmd="./gradlew"
        chmod +x "./gradlew"
    fi
    
    # Set debugMode based on BUILD_MODE
    local debug_mode="none"
    if [[ "$BUILD_MODE" == "$BUILD_MODE_RELEASE" ]]; then
        debug_mode="release"
        log_info "Building IDEA plugin in release mode (debugMode=release)"
    elif [[ "$BUILD_MODE" == "$BUILD_MODE_DEBUG" ]]; then
        debug_mode="idea"
        log_info "Building IDEA plugin in debug mode (debugMode=idea)"
    fi
    
    # Build plugin with debugMode property
    execute_cmd "$gradle_cmd -PdebugMode=$debug_mode buildPlugin --info" "IDEA plugin build"
    
    # Find generated plugin
    local plugin_file
    plugin_file=$(find "$IDEA_BUILD_DIR/build/distributions" \( -name "*.zip" -o -name "*.jar" \) -type f | sort -r | head -n 1)
    
    if [[ -n "$plugin_file" ]]; then
        log_success "IDEA plugin built: $plugin_file"
        export IDEA_PLUGIN_FILE="$plugin_file"
    else
        log_warn "IDEA plugin file not found in build/distributions"
    fi
    
    # Clean temporary resources after successful build
    clean_idea_resources_postbuild
}

# Clean build artifacts
clean_build() {
    log_step "Cleaning build artifacts..."
    
    # Clean VSCode build
    if [[ -d "$PLUGIN_BUILD_DIR" ]]; then
        cd "$PLUGIN_BUILD_DIR"
        [[ -d "bin" ]] && remove_dir "bin"
        [[ -d "src/dist" ]] && remove_dir "src/dist"
        [[ -d "node_modules" ]] && remove_dir "node_modules"
    fi
    
    # Clean base build
    if [[ -d "$BASE_BUILD_DIR" ]]; then
        cd "$BASE_BUILD_DIR"
        [[ -d "dist" ]] && remove_dir "dist"
        [[ -d "node_modules" ]] && remove_dir "node_modules"
    fi
    
    # Clean IDEA build
    if [[ -d "$IDEA_BUILD_DIR" ]]; then
        cd "$IDEA_BUILD_DIR"
        [[ -d "build" ]] && remove_dir "build"
        [[ -d "$VSCODE_PLUGIN_TARGET_DIR" ]] && remove_dir "$VSCODE_PLUGIN_TARGET_DIR"
        # Clean builtin Node.js from resources directory
        [[ -d "$BUILTIN_NODEJS_DIR" ]] && remove_dir "$BUILTIN_NODEJS_DIR"
        # Clean asset files from resources directory
        local scripts_resource_dir="$IDEA_BUILD_DIR/src/main/resources/scripts"
        if [[ -d "$scripts_resource_dir" ]]; then
            [[ -f "$scripts_resource_dir/setup-node.sh" ]] && remove_file "$scripts_resource_dir/setup-node.sh"
            [[ -f "$scripts_resource_dir/setup-node.bat" ]] && remove_file "$scripts_resource_dir/setup-node.bat"
            [[ -f "$scripts_resource_dir/NODE_SETUP_README.md" ]] && remove_file "$scripts_resource_dir/NODE_SETUP_README.md"
            # Remove directory if empty
            if [[ -z "$(ls -A "$scripts_resource_dir" 2>/dev/null)" ]]; then
                remove_dir "$scripts_resource_dir"
            fi
        fi
    fi
    
    # Clean debug resources
    [[ -d "$PROJECT_ROOT/debug-resources" ]] && remove_dir "$PROJECT_ROOT/debug-resources"
    
    # Clean temp directories
    find /tmp -name "${TEMP_PREFIX}*" -type d -exec rm -rf {} + 2>/dev/null || true
    
    log_success "Build artifacts cleaned"
}

# Cleanup build environment
cleanup_build() {
    if [[ -n "${BUILD_TEMP_DIR:-}" && -d "${BUILD_TEMP_DIR:-}" ]]; then
        remove_dir "$BUILD_TEMP_DIR"
    fi
}

# Set up cleanup trap
trap cleanup_build EXIT