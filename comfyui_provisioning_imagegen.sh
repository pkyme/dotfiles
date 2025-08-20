#!/bin/bash

# ComfyUI Provisioning Script for vast.ai
# This script automatically sets up ComfyUI with custom nodes and models
# 
# Environment Variables:
#   HF_TOKEN - Hugging Face token for authentication (optional but recommended)
#            - Get your token from: https://huggingface.co/settings/tokens
#            - Usage: export HF_TOKEN="your_token_here" && ./script.sh
#
# Installation Control Variables:
#   INSTALL_COMFYUI - Install and run ComfyUI core (default: true)
#   INSTALL_CUSTOM_NODES - Install custom nodes (default: true)
#
# Model Architecture Control Variables (set to "true" to download):
#   DOWNLOAD_ALL - Download all models (overrides individual settings, default: false)
#   DOWNLOAD_{GROUP_NAME} - Download specific model group (see MODEL_GROUPS below)
#
# Performance Enhancement Variables:
#   INSTALL_SAGE_ATTENTION - Install SageAttention library for faster attention computation (default: false)
#                          - When enabled, ComfyUI will automatically use --use-sage-attention flag
#   INSTALL_PYTORCH_NIGHTLY - Install latest PyTorch nightly build for cutting-edge features and performance (default: false)
#                           - Uses CUDA 12.8 compatible builds

# Configuration
COMFYUI_DIR="ComfyUI"
LISTEN_HOST="0.0.0.0"  # Changed from localhost for vast.ai accessibility
LISTEN_PORT="3000"

# Installation control
INSTALL_COMFYUI="${INSTALL_COMFYUI:-true}"
INSTALL_CUSTOM_NODES="${INSTALL_CUSTOM_NODES:-true}"

# Global download control
DOWNLOAD_ALL="${DOWNLOAD_ALL:-false}"

# Performance enhancement control
INSTALL_SAGE_ATTENTION="${INSTALL_SAGE_ATTENTION:-false}"
INSTALL_PYTORCH_NIGHTLY="${INSTALL_PYTORCH_NIGHTLY:-false}"

# ================================
# MODEL GROUP CONFIGURATION
# ================================
# To add a new model group:
# 1. Add it to the MODEL_GROUPS array
# 2. Define the models in the corresponding function below
# 3. Set the default download behavior
# That's it! No other changes needed.

# Define all available model groups
MODEL_GROUPS=(
    "SDXL:false"          # SDXL models - disabled by default
    "FLUX:false"          # Flux models - disabled by default  
    "SD3:false"           # SD3 models - disabled by default
    "CONTROLNET_EXTRAS:false"  # Extra ControlNet models - disabled by default
    "IPADAPTER:false"     # IP-Adapter models - disabled by default
    "WAN21T2V14B:false"      # Wan 2.1 Text to Video 14B
)

# Model definitions for each group
# Add new groups by creating a new function following this pattern:
# define_models_GROUPNAME() { MODELS=("url:type" "url:type" ...); }

define_models_SDXL() {
    MODELS=(
        "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors:checkpoints"
        "https://huggingface.co/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model_promax.safetensors:controlnet"
    )
}

define_models_FLUX() {
    MODELS=(
        "https://huggingface.co/city96/FLUX.1-dev-gguf/resolve/main/flux1-dev-Q8_0.gguf:diffusion_models"
        "https://huggingface.co/Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro/resolve/main/diffusion_pytorch_model.safetensors:controlnet"
        "https://huggingface.co/StableDiffusionVN/Flux/resolve/main/Vae/flux_vae.safetensors:vae"
        "https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf/resolve/main/t5-v1_1-xxl-encoder-Q8_0.gguf:text_encoders"
        "https://huggingface.co/QuantStack/FLUX.1-Kontext-dev-GGUF/resolve/main/flux1-kontext-dev-Q8_0.gguf:unet"
    )
}

define_models_SD3() {
    MODELS=(
        "https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/text_encoders/clip_l.safetensors:text_encoders"
        # Add more SD3 models here as needed
    )
}

define_models_CONTROLNET_EXTRAS() {
    MODELS=(
        # Additional ControlNet models that work across architectures
        # Add more here as needed
    )
}

define_models_IPADAPTER() {
    MODELS=(
        # "https://huggingface.co/InstantX/FLUX.1-dev-IP-Adapter/resolve/main/ip-adapter.bin:ipadapter-flux"
        # "https://huggingface.co/google/siglip-so400m-patch14-384/resolve/main/model.safetensors:clip_vision"
        # "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl.safetensors:ipadapter"
        # "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors:clip_vision"
    )
}

define_models_WAN21T2V14B() {
    MODELS=(
        "https://huggingface.co/city96/Wan2.1-T2V-14B-gguf/resolve/main/wan2.1-t2v-14b-Q8_0.gguf:diffusion_models"
        "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors:vae"
        "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors:text_encoders"
    )
}

# ================================
# END MODEL CONFIGURATION
# ================================

# Initialize download variables based on MODEL_GROUPS configuration
init_download_variables() {
    for group_config in "${MODEL_GROUPS[@]}"; do
        local group_name="${group_config%:*}"
        local default_value="${group_config#*:}"
        local var_name="DOWNLOAD_${group_name}"
        
        # Set the variable to the environment value or the default
        declare -g "$var_name"="${!var_name:-$default_value}"
    done
}

# Logging functions
log_info() {
    echo -e "[INFO] $1"
}

log_success() {
    echo -e "[SUCCESS] $1"
}

log_warning() {
    echo -e "[WARNING] $1"
}

log_error() {
    echo -e "[ERROR] $1"
}

# Function to log installation decisions
log_installation_decisions() {
    log_info "Installation configuration:"
    
    local comfyui_status="❌"
    if [ "$INSTALL_COMFYUI" = "true" ]; then
        comfyui_status="✅"
    fi
    log_info "  INSTALL_COMFYUI: $INSTALL_COMFYUI $comfyui_status"
    
    local nodes_status="❌"
    if [ "$INSTALL_CUSTOM_NODES" = "true" ]; then
        nodes_status="✅"
    fi
    log_info "  INSTALL_CUSTOM_NODES: $INSTALL_CUSTOM_NODES $nodes_status"
}

# Function to check if a model group should be downloaded
should_download_group() {
    local group_name="$1"
    local var_name="DOWNLOAD_${group_name}"
    local group_value="${!var_name:-false}"
    
    # If DOWNLOAD_ALL is true, download everything
    if [ "$DOWNLOAD_ALL" = "true" ]; then
        return 0
    fi
    
    # Otherwise check the specific group variable
    if [ "$group_value" = "true" ]; then
        return 0
    else
        return 1
    fi
}

# Function to log download decisions
log_download_decisions() {
    log_info "Model download configuration:"
    
    if [ "$DOWNLOAD_ALL" = "true" ]; then
        log_info "  DOWNLOAD_ALL: true (all models will be downloaded)"
        return
    fi
    
    for group_config in "${MODEL_GROUPS[@]}"; do
        local group_name="${group_config%:*}"
        local var_name="DOWNLOAD_${group_name}"
        local var_value="${!var_name:-false}"
        local status="❌"
        if [ "$var_value" = "true" ]; then
            status="✅"
        fi
        log_info "  $var_name: $var_value $status"
    done
}

# Function to install Hugging Face CLI if not present
install_hf_cli() {
    if ! command -v huggingface-hub &> /dev/null; then
        log_info "Installing Hugging Face CLI..."
        pip install huggingface-hub[cli]
        log_success "Hugging Face CLI installed"
    else
        log_info "Hugging Face CLI already installed"
    fi
}

# Function to check for HF token
check_hf_token() {
    if [ -n "${HF_TOKEN:-}" ]; then
        log_info "HF_TOKEN found - will use for authenticated downloads"
    else
        log_warning "No HF_TOKEN environment variable found. Downloads will be limited to public models only."
        log_info "To access private/gated models, set HF_TOKEN environment variable with your Hugging Face token"
    fi
}

# Function to extract node name from GitHub URL
get_node_name_from_url() {
    local url="$1"
    # Extract the repository name from the URL (everything after the last /)
    echo "${url##*/}" | sed 's/\.git$//'
}

# Function to install a custom node
install_custom_node() {
    local repo_url="$1"
    local node_name
    
    # Automatically extract node name from URL
    node_name=$(get_node_name_from_url "$repo_url")
    
    log_info "Installing custom node: $node_name"
    
    if [ ! -d "custom_nodes/$node_name" ]; then
        git clone "$repo_url" "custom_nodes/$node_name"
        
        # Check if requirements.txt exists and install if found
        if [ -f "custom_nodes/$node_name/requirements.txt" ]; then
            log_info "Installing requirements for $node_name"
            pip install -r "custom_nodes/$node_name/requirements.txt"
        else
            log_info "No requirements.txt found for $node_name, skipping pip install"
        fi
        
        log_success "Installed $node_name"
    else
        log_warning "$node_name already exists, skipping"
    fi
}

# Function to parse Hugging Face URL and extract repo info
parse_hf_url() {
    local url="$1"
    local repo_id
    local filename
    
    # Extract repo_id (format: username/repo-name)
    repo_id=$(echo "$url" | sed -n 's|.*huggingface\.co/\([^/]*/[^/]*\)/.*|\1|p')
    
    # Extract filename from the end of the URL
    filename=$(echo "$url" | sed -n 's|.*/\([^/]*\)$|\1|p')
    
    echo "$repo_id:$filename"
}

# Function to extract model path from HuggingFace URL (preserving original structure)
get_model_output_path() {
    local model_type="$1"
    local hf_url="$2"
    
    # Extract the path between huggingface.co and resolve (username/repo-name)
    local path_component=$(echo "$hf_url" | sed -n 's|.*huggingface\.co/\([^/]*/[^/]*\)/.*resolve.*|\1|p')
    
    # Return the full path
    echo "models/$model_type/$path_component"
}

# Function to download a model file using HuggingFace CLI
download_model_hf() {
    local model_type="$1"
    local hf_url="$2"
    
    local parsed_info
    local repo_id
    local filename
    local output_dir
    local url_subfolder
    local download_cmd
    
    # Validate inputs
    if [ -z "$model_type" ] || [ -z "$hf_url" ]; then
        log_error "download_model_hf called with empty parameters: model_type='$model_type', hf_url='$hf_url'"
        return 1
    fi
    
    # Parse the HuggingFace URL
    parsed_info=$(parse_hf_url "$hf_url")
    repo_id=$(echo "$parsed_info" | cut -d':' -f1)
    filename=$(echo "$parsed_info" | cut -d':' -f2)
    
    # Validate parsed info
    if [ -z "$repo_id" ] || [ -z "$filename" ]; then
        log_error "Failed to parse HuggingFace URL: $hf_url"
        log_error "Parsed - repo_id: '$repo_id', filename: '$filename'"
        return 1
    fi
    
    # Get output directory preserving the original HF path structure
    output_dir=$(get_model_output_path "$model_type" "$hf_url")
    
    # Extract subfolder from URL if present (path after resolve/main/ or resolve/branch/)
    url_subfolder=$(echo "$hf_url" | sed -n 's|.*resolve/[^/]*/\(.*\)/[^/]*$|\1|p')
    
    log_info "Downloading $model_type model: $filename from $repo_id to $output_dir/"
    
    # Create directory if it doesn't exist
    mkdir -p "$output_dir"
    
    # Check if file already exists
    if [ -f "$output_dir/$filename" ]; then
        log_warning "File $filename already exists, skipping download"
        return 0
    fi
    
    # Build the base download command
    download_cmd="hf download \"$repo_id\""
    
    # Add token if available
    if [ -n "${HF_TOKEN:-}" ]; then
        download_cmd="$download_cmd --token \"$HF_TOKEN\""
    fi
    
    # Add common parameters
    download_cmd="$download_cmd --local-dir \"$output_dir\""
    
    # Download the file using HF CLI
    if [ -n "$url_subfolder" ]; then
        # Download file with subfolder
        download_cmd="$download_cmd \"$url_subfolder/$filename\""
        if eval "$download_cmd"; then
            # Move file from subfolder to main directory to maintain expected structure
            if [ -f "$output_dir/$url_subfolder/$filename" ]; then
                mv "$output_dir/$url_subfolder/$filename" "$output_dir/$filename"
                rmdir "$output_dir/$url_subfolder" 2>/dev/null || true
            fi
            log_success "Downloaded $filename"
        else
            log_error "Failed to download $filename"
            return 1
        fi
    else
        # Download file directly
        download_cmd="$download_cmd \"$filename\""
        if eval "$download_cmd"; then
            log_success "Downloaded $filename"
        else
            log_error "Failed to download $filename"
            return 1
        fi
    fi
}

# Function to install PyTorch nightly
install_pytorch_nightly() {
    if [ "$INSTALL_PYTORCH_NIGHTLY" = "true" ]; then
        log_info "Installing PyTorch nightly build for cutting-edge features and performance..."
        log_warning "This will replace the current PyTorch installation with the latest nightly build"
        
        pip3 install --upgrade --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128
        
        log_success "PyTorch nightly build installed"
        
        # Log the installed version
        local torch_version=$(python -c "import torch; print(f'PyTorch {torch.version.__version__} (CUDA: {torch.version.cuda})')" 2>/dev/null || echo "Unable to detect version")
        log_info "Installed version: $torch_version"
    else
        log_info "Skipping PyTorch nightly installation (INSTALL_PYTORCH_NIGHTLY is not set to true)"
    fi
}

# Function to install SageAttention library
install_sage_attention() {
    if [ "$INSTALL_SAGE_ATTENTION" = "true" ]; then
        log_info "Installing SageAttention library for faster attention computation..."
        
        if [ ! -d "SageAttention" ]; then
            git clone https://github.com/thu-ml/SageAttention.git
            cd SageAttention/
            python setup.py install  # or pip install -e .
            cd ..
            log_success "SageAttention library installed"
        else
            log_warning "SageAttention directory already exists, skipping installation"
        fi
    else
        log_info "Skipping SageAttention installation (INSTALL_SAGE_ATTENTION is not set to true)"
    fi
}

install_comfyui_core() {
    if [ "$INSTALL_COMFYUI" = "true" ]; then
        log_info "Installing ComfyUI core..."
        
        if [ ! -d "$COMFYUI_DIR" ]; then
            git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
            cd "$COMFYUI_DIR"
            pip install -r requirements.txt
            log_success "ComfyUI core installed"
        else
            log_warning "ComfyUI directory already exists"
            cd "$COMFYUI_DIR"
        fi
    else
        log_info "Skipping ComfyUI core installation (INSTALL_COMFYUI is not set to true)"
        # Still need to change to the directory if it exists for other operations
        if [ -d "$COMFYUI_DIR" ]; then
            cd "$COMFYUI_DIR"
        fi
    fi
}

# Function to install all custom nodes
install_custom_nodes() {
    if [ "$INSTALL_CUSTOM_NODES" = "true" ]; then
        log_info "Installing custom nodes..."
        
        # Define custom nodes to install (just GitHub URLs)
        local custom_node_urls=(
            "https://github.com/ltdrdata/ComfyUI-Manager.git"
            "https://github.com/kijai/ComfyUI-KJNodes.git"
            "https://github.com/aria1th/ComfyUI-LogicUtils.git"
            "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
            "https://github.com/Fannovel16/comfyui_controlnet_aux.git"
            "https://github.com/rgthree/rgthree-comfy.git"
            "https://github.com/city96/ComfyUI-GGUF"
            "https://github.com/yolain/ComfyUI-Easy-Use"
            "https://github.com/StableLlama/ComfyUI-basic_data_handling"
            "https://github.com/munkyfoot/ComfyUI-TextOverlay.git"
            "https://github.com/Nourepide/ComfyUI-Allor.git"
            "https://github.com/kijai/ComfyUI-segment-anything-2.git"
            "https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
            # "https://github.com/Shakker-Labs/ComfyUI-IPAdapter-Flux.git"
            # "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
        )
        
        for repo_url in "${custom_node_urls[@]}"; do
            install_custom_node "$repo_url"
        done
        
        log_success "All custom nodes installed"
    else
        log_info "Skipping custom nodes installation (INSTALL_CUSTOM_NODES is not set to true)"
    fi
}

# Function to download models for a specific group
download_model_group() {
    local group_name="$1"
    
    if should_download_group "$group_name"; then
        log_info "Downloading $group_name models..."
        
        # Call the corresponding define_models function
        local define_function="define_models_${group_name}"
        if declare -f "$define_function" > /dev/null; then
            # Clear MODELS array and populate it
            MODELS=()
            $define_function
            
            # Download each model in the group
            for url_type in "${MODELS[@]}"; do
                if [ -n "$url_type" ]; then  # Skip empty entries
                    # Extract URL (everything before the last colon)
                    local extracted_url="${url_type%:*}"
                    # Extract model type (everything after the last colon)
                    local extracted_type="${url_type##*:}"
                    
                    # log_info "Processing: $url_type"
                    # log_info "  -> URL: $extracted_url"
                    # log_info "  -> Type: $extracted_type"
                    
                    # Skip if URL and model_type are the same (no colon found)
                    if [ "$extracted_url" = "$extracted_type" ]; then
                        log_error "Invalid model entry format: $url_type (expected format: url:type)"
                        continue
                    fi
                    
                    download_model_hf "$extracted_type" "$extracted_url"
                fi
            done
            
            log_success "$group_name models downloaded"
        else
            log_error "No model definition function found for $group_name"
        fi
    else
        log_info "Skipping $group_name models (DOWNLOAD_${group_name} is not set to true)"
    fi
}

# Function to download all models
download_models() {
    log_info "Starting model downloads..."
    
    # Install HF CLI and check for token
    install_hf_cli
    check_hf_token
    
    # Log download decisions
    log_download_decisions
    
    # Download each model group
    for group_config in "${MODEL_GROUPS[@]}"; do
        local group_name="${group_config%:*}"
        download_model_group "$group_name"
    done
    
    log_success "Model download process completed"
}

# Function to build ComfyUI launch command
build_comfyui_command() {
    local base_command="cd $COMFYUI_DIR && python main.py --listen $LISTEN_HOST --port $LISTEN_PORT"
    
    # Add SageAttention flag if enabled
    if [ "$INSTALL_SAGE_ATTENTION" = "true" ]; then
        base_command="$base_command --use-sage-attention"
    fi
    
    echo "$base_command"
}

# Function to start ComfyUI
start_comfyui() {
    if [ "$INSTALL_COMFYUI" = "true" ]; then
        local comfyui_args="--listen $LISTEN_HOST --port $LISTEN_PORT"
        
        # Add SageAttention flag if enabled
        if [ "$INSTALL_SAGE_ATTENTION" = "true" ]; then
            comfyui_args="$comfyui_args --use-sage-attention"
            log_info "SageAttention enabled - using --use-sage-attention flag"
        fi
        
        log_info "Starting ComfyUI on $LISTEN_HOST:$LISTEN_PORT"
        if [ "$INSTALL_SAGE_ATTENTION" = "true" ]; then
            log_info "SageAttention optimization active"
        fi
        
        python main.py $comfyui_args
    else
        log_info "ComfyUI installation was skipped - cannot start ComfyUI"
        log_info "To start ComfyUI later, set INSTALL_COMFYUI=true and re-run the script"
    fi
}

# Main execution function
main() {
    log_info "Starting ComfyUI provisioning script..."

    cd /workspace/
    # Cause the script to exit on failure.
    set -eo pipefail

    # Initialize download variables from MODEL_GROUPS configuration
    init_download_variables

    # Log installation and download decisions
    log_installation_decisions

    # Activate the main virtual environment
    . /venv/main/bin/activate
    
    # Install performance enhancements first (PyTorch nightly should be installed before other dependencies)
    install_pytorch_nightly
    
    install_comfyui_core
    install_sage_attention
    install_custom_nodes
    download_models
    
    log_success "ComfyUI provisioning completed successfully!"
    
    # Start ComfyUI if not in setup-only mode and if ComfyUI was installed
    if [ "${1:-}" != "--setup-only" ]; then
        start_comfyui
    else
        if [ "$INSTALL_COMFYUI" = "true" ]; then
            local start_command=$(build_comfyui_command)
            log_info "Setup complete. Run '$start_command' to start ComfyUI"
        else
            log_info "Setup complete. ComfyUI installation was skipped."
            log_info "To install and start ComfyUI, set INSTALL_COMFYUI=true and re-run the script"
        fi
    fi
}

# Handle script interruption
cleanup() {
    log_warning "Script interrupted. Cleaning up..."
    exit 1
}

trap cleanup SIGINT SIGTERM

# Run main function with all arguments
main "$@"