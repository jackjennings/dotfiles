#!/bin/sh

brew services start ollama >/dev/null

for i in $(seq 1 30); do
  if curl -fs http://localhost:11434/api/tags >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

ollama pull qwen2.5:7b
