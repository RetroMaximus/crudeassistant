#!/usr/bin/env python3
"""
AI Assistant API Server
"""

import json
import logging
from fastapi import FastAPI, HTTPException, Header, Depends
from pydantic import BaseModel
import requests
import os
from typing import Optional, Dict, Any

# Configuration
CONFIG_FILE = "config/models.json"
OLLAMA_BASE_URL = "http://localhost:11434"

app = FastAPI(title="AI Assistant API", description="AI Assistant")

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ChatRequest(BaseModel):
    message: str
    model: Optional[str] = None
    temperature: Optional[float] = None
    max_tokens: Optional[int] = 1000
    json_mode: bool = True
    low_memory: bool = False

class ChatResponse(BaseModel):
    response: Dict[str, Any]
    model_used: str
    tokens_used: Optional[int] = None

def load_config():
    """Load model configuration"""
    with open(CONFIG_FILE, 'r') as f:
        return json.load(f)

def get_active_model():
    """Get currently active model"""
    config = load_config()
    active_key = config.get('active_model', 'codellama')
    active_model = config['available_models'][active_key]
    return active_key, active_model

def simple_auth(authorization: str = Header(...)):
    """Simple authentication"""
    expected_token = os.getenv("AI_ASSISTANT_TOKEN", "free-tier-token")
    
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    
    token = authorization[7:]
    if token != expected_token:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    return token

@app.get("/")
async def root():
    return {"message": "AI Assistant API is running"}

@app.get("/models")
async def list_models():
    """List all available models"""
    config = load_config()
    active_model = config.get('active_model')
    
    models = {}
    for key, model_info in config['available_models'].items():
        models[key] = {
            "name": model_info['name'],
            "description": model_info['description'],
            "tags": model_info['tags'],
            "is_active": key == active_model
        }
    
    return {"models": models, "active_model": active_model}

@app.post("/models/switch")
async def switch_active_model(model_key: str, auth: str = Depends(simple_auth)):
    """Switch the active model"""
    config = load_config()
    
    if model_key not in config['available_models']:
        raise HTTPException(status_code=400, detail=f"Model {model_key} not available")
    
    config['active_model'] = model_key
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config, f, indent=2)
    
    logger.info(f"Switched to model: {model_key}")
    return {"status": "success", "active_model": model_key}

@app.post("/chat")
async def chat_with_ai(request: ChatRequest, auth: str = Depends(simple_auth)):
    """Chat with the AI assistant"""
    
    # Apply low memory setting
    if request.low_memory:
        request.max_tokens = min(request.max_tokens, 512)
    
    # Determine which model to use
    model_key = request.model
    if not model_key:
        model_key, active_model = get_active_model()
    else:
        config = load_config()
        if model_key not in config['available_models']:
            raise HTTPException(status_code=400, detail=f"Model {model_key} not available")
        active_model = config['available_models'][model_key]
    
    model_name = active_model['name']
    temperature = request.temperature or active_model.get('default_temperature', 0.7)
    
    # Prepare the prompt for JSON responses if requested
    if request.json_mode:
        prompt = f"""Please provide a JSON-structured response for the following request. 
        The response should be valid JSON and include relevant information.

        Request: {request.message}

        Respond with JSON only:"""
    else:
        prompt = request.message
    
    # Call Ollama API
    try:
        response = requests.post(
            f"{OLLAMA_BASE_URL}/api/generate",
            json={
                "model": model_name,
                "prompt": prompt,
                "stream": False,
                "options": {
                    "temperature": temperature,
                    "num_predict": request.max_tokens
                }
            },
            timeout=120
        )
        response.raise_for_status()
        
        result = response.json()
        
        # Try to parse JSON response if json_mode is enabled
        response_text = result.get('response', '')
        if request.json_mode:
            try:
                # Extract JSON from response if it's wrapped in text
                if '```json' in response_text:
                    json_str = response_text.split('```json')[1].split('```')[0].strip()
                    parsed_response = json.loads(json_str)
                else:
                    parsed_response = json.loads(response_text)
            except json.JSONDecodeError:
                # If JSON parsing fails, return as text
                parsed_response = {"response": response_text}
        else:
            parsed_response = {"response": response_text}
        
        return ChatResponse(
            response=parsed_response,
            model_used=model_key,
            tokens_used=result.get('eval_count')
        )
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Error calling Ollama API: {e}")
        raise HTTPException(status_code=500, detail="Error communicating with AI model")

@app.get("/status")
async def get_status():
    """Get system status"""
    try:
        response = requests.get(f"{OLLAMA_BASE_URL}/api/tags")
        models_available = response.json().get('models', [])
        
        active_key, active_model = get_active_model()
        
        return {
            "status": "running",
            "ollama_available": True,
            "active_model": active_key,
            "available_models": len(models_available)
        }
    except:
        return {
            "status": "error",
            "ollama_available": False,
            "active_model": None,
            "available_models": 0
        }

if __name__ == "__main__":
    import uvicorn
    
    ssl_keyfile = "ssl/key.pem"
    ssl_certfile = "ssl/cert.pem"
    
    if os.path.exists(ssl_keyfile) and os.path.exists(ssl_certfile):
        uvicorn.run(app, host="0.0.0.0", port=8000, ssl_keyfile=ssl_keyfile, ssl_certfile=ssl_certfile)
    else:
        uvicorn.run(app, host="0.0.0.0", port=8000)
