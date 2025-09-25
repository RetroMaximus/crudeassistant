#!/usr/bin/env python3
"""
Optimized API Server for Low VRAM Hardware
"""

import os
import psutil
import GPUtil
from scripts.api_server import *

class OptimizedChatRequest(ChatRequest):
    max_tokens: Optional[int] = 512  # Reduced for low VRAM
    low_memory_mode: bool = True

@app.post("/chat/optimized")
async def optimized_chat(request: OptimizedChatRequest, auth: str = Depends(simple_auth)):
    """Optimized chat endpoint for low VRAM hardware"""
    
    # Check available VRAM
    try:
        gpus = GPUtil.getGPUs()
        if gpus:
            gpu = gpus[0]
            if gpu.memoryFree < 1000:  # Less than 1GB free
                return {
                    "warning": "Low VRAM available, response may be slow",
                    "suggestion": "Try using tinyllama model",
                    "vram_free_mb": gpu.memoryFree
                }
    except:
        pass  # GPU monitoring not available
    
    # Force smaller context for low memory mode
    if request.low_memory_mode:
        request.max_tokens = min(request.max_tokens, 512)
    
    return await chat_with_ai(request, auth)

@app.get("/system/status")
async def system_status():
    """Detailed system status for hardware monitoring"""
    status_info = await get_status()
    
    # Add hardware information
    status_info["cpu_percent"] = psutil.cpu_percent()
    status_info["memory_percent"] = psutil.virtual_memory().percent
    
    try:
        gpus = GPUtil.getGPUs()
        if gpus:
            gpu = gpus[0]
            status_info["gpu"] = {
                "name": gpu.name,
                "memory_total_mb": gpu.memoryTotal,
                "memory_used_mb": gpu.memoryUsed,
                "memory_free_mb": gpu.memoryFree,
                "load_percent": gpu.load * 100
            }
    except:
        status_info["gpu"] = "Not available"
    
    return status_info
