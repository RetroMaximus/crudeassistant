#!/usr/bin/env python3

import json
import requests
import pyaudio
import wave
from gtts import gTTS
import pygame
import time
import threading

class CruddyRobot:
    def __init__(self, config_file="config.json"):
        with open(config_file) as f:
            self.config = json.load(f)
        
        self.api_url = self.config["api_url"]
        self.auth_token = self.config["auth_token"]
        
        # Audio setup
        self.chunk = 1024
        self.format = pyaudio.paInt16
        self.channels = 1
        self.rate = 44100
        self.record_seconds = 5
        
        pygame.mixer.init()
    
    def listen(self):
        """Record audio from microphone"""
        print("🎤 Listening...")
        audio = pyaudio.PyAudio()
        
        stream = audio.open(format=self.format, channels=self.channels,
                           rate=self.rate, input=True,
                           frames_per_buffer=self.chunk)
        
        frames = []
        for i in range(0, int(self.rate / self.chunk * self.record_seconds)):
            data = stream.read(self.chunk)
            frames.append(data)
        
        stream.stop_stream()
        stream.close()
        audio.terminate()
        
        # Save recording
        with wave.open("recording.wav", 'wb') as wf:
            wf.setnchannels(self.channels)
            wf.setsampwidth(audio.get_sample_size(self.format))
            wf.setframerate(self.rate)
            wf.writeframes(b''.join(frames))
        
        return "recording.wav"
    
    def send_to_ai(self, message):
        """Send message to AI assistant"""
        headers = {
            "Authorization": f"Bearer {self.auth_token}",
            "Content-Type": "application/json"
        }
        
        data = {
            "message": message,
            "json_mode": False,
            "low_memory": True
        }
        
        try:
            response = requests.post(
                f"{self.api_url}/chat",
                headers=headers,
                json=data,
                verify=False  # For self-signed certs
            )
            return response.json()["response"]["response"]
        except Exception as e:
            return f"Error communicating with AI: {e}"
    
    def speak(self, text):
        """Convert text to speech and play it"""
        print(f"🗣️ Cruddy says: {text}")
        tts = gTTS(text=text, lang='en', slow=False)
        tts.save("response.mp3")
        
        pygame.mixer.music.load("response.mp3")
        pygame.mixer.music.play()
        
        while pygame.mixer.music.get_busy():
            time.sleep(0.1)
    
    def move_servo(self, servo, angle):
        """Move a servo to specific angle"""
        print(f"🦾 Moving {servo} to {angle} degrees")
        # GPIO control would go here
    
    def simple_chat(self):
        """Simple chat loop"""
        print("🤖 Cruddy is ready! Press Ctrl+C to exit")
        
        while True:
            try:
                input("Press Enter to start listening...")
                
                # Record audio
                audio_file = self.listen()
                
                # For now, use text input instead of speech recognition
                message = input("Type your message: ")
                
                # Get AI response
                response = self.send_to_ai(message)
                
                # Speak response
                self.speak(response)
                
                # Animate (simple servo movements)
                self.move_servo("head", 30)
                time.sleep(0.5)
                self.move_servo("head", 0)
                
            except KeyboardInterrupt:
                print("\n👋 Cruddy going to sleep...")
                break

if __name__ == "__main__":
    robot = CruddyRobot()
    robot.simple_chat()
