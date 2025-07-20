#!/bin/bash

# ComfyUI Provisioning Script for vast.ai
# This script automatically sets up ComfyUI with custom nodes and models
# 
# Environment Variables:
#   HF_TOKEN - Hugging Face token for authentication (optional but recommended)
#            - Get your token from: https://huggingface.co/settings/tokens
#            - Usage: export HF_TOKEN="your_token_here" && ./script.sh

# Configuration
COMFYUI_DIR="ComfyUI"
LISTEN_HOST="0.0.0.0"  # Changed from localhost for vast.ai accessibility
LISTEN_PORT="3000"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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
    repo_id=$(echo "$url" | sed -n 's|.*huggingface\.co/\([^/]*/[^/]*\).*|\1|p')
    
    # Extract filename from the end of the URL
    filename=$(echo "$url" | sed -n 's|.*/\([^/]*\)$|\1|p')
    
    echo "$repo_id:$filename"
}

# Function to extract model path from HuggingFace URL (preserving original structure)
get_model_output_path() {
    local model_type="$1"
    local hf_url="$2"
    
    # Extract the path between huggingface.co and resolve
    local path_component=$(echo "$hf_url" | sed -n 's|.*huggingface\.co/\([^/]*\)/\([^/]*\).*resolve.*|\1/\2|p')
    
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
    
    # Parse the HuggingFace URL
    parsed_info=$(parse_hf_url "$hf_url")
    repo_id=$(echo "$parsed_info" | cut -d':' -f1)
    filename=$(echo "$parsed_info" | cut -d':' -f2)
    
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
    download_cmd="huggingface-cli download \"$repo_id\""
    
    # Add token if available
    if [ -n "${HF_TOKEN:-}" ]; then
        download_cmd="$download_cmd --token \"$HF_TOKEN\""
    fi
    
    # Add common parameters
    download_cmd="$download_cmd --local-dir \"$output_dir\" --local-dir-use-symlinks False"
    
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

# Function to install ComfyUI core
install_comfyui_core() {
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
}

# Function to install all custom nodes
install_custom_nodes() {
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
        # "https://github.com/Shakker-Labs/ComfyUI-IPAdapter-Flux.git"
        # "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
    )
    
    for repo_url in "${custom_node_urls[@]}"; do
        install_custom_node "$repo_url"
    done
    
    log_success "All custom nodes installed"
}

# Function to download all models
download_models() {
    log_info "Downloading models..."
    
    # Install HF CLI and check for token
    install_hf_cli
    check_hf_token
    
    # Define models to download (huggingface_url:model_type pairs)
    declare -A model_downloads=(
        ["https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors"]="checkpoints"
        ["https://huggingface.co/city96/FLUX.1-dev-gguf/resolve/main/flux1-dev-Q8_0.gguf"]="diffusion_models"
        ["https://huggingface.co/Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro/resolve/main/diffusion_pytorch_model.safetensors"]="controlnet"
        ["https://huggingface.co/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model_promax.safetensors"]="controlnet"
        ["https://huggingface.co/StableDiffusionVN/Flux/resolve/main/Vae/flux_vae.safetensors"]="vae"
        ["https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf/resolve/main/t5-v1_1-xxl-encoder-Q8_0.gguf"]="text_encoders"
        ["https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/text_encoders/clip_l.safetensors"]="text_encoders"
        # ["https://huggingface.co/InstantX/FLUX.1-dev-IP-Adapter/resolve/main/ip-adapter.bin"]="ipadapter-flux"
        # ["https://huggingface.co/google/siglip-so400m-patch14-384/resolve/main/model.safetensors"]="clip_vision"
        # ["https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl.safetensors"]="ipadapter"
        # ["https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors"]="clip_vision"
    )
    
    for url in "${!model_downloads[@]}"; do
        local model_type="${model_downloads[$url]}"
        download_model_hf "$model_type" "$url"
    done
    
    log_success "All models downloaded"
}

# Function to start ComfyUI
start_comfyui() {
    log_info "Starting ComfyUI on $LISTEN_HOST:$LISTEN_PORT"
    python main.py --listen "$LISTEN_HOST" --port "$LISTEN_PORT"
}

# Main execution function
main() {
    log_info "Starting ComfyUI provisioning script..."

    cd /workspace/
    # Cause the script to exit on failure.
    set -eo pipefail

    # Activate the main virtual environment
    . /venv/main/bin/activate
    
    install_comfyui_core
    install_custom_nodes
    download_models
    
    log_success "ComfyUI provisioning completed successfully!"
    
    # Start ComfyUI if not in setup-only mode
    if [ "${1:-}" != "--setup-only" ]; then
        start_comfyui
    else
        log_info "Setup complete. Run 'cd $COMFYUI_DIR && python main.py --listen $LISTEN_HOST --port $LISTEN_PORT' to start ComfyUI"
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