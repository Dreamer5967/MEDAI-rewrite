#!/bin/bash
# Quick local development startup

echo "Starting backend..."
cd backend
pip install -r requirements.txt -q
cp -n ../.env.example .env 2>/dev/null || true
uvicorn server:app --reload --port 8000 &
BACKEND_PID=$!

echo "Starting frontend..."
cd ../frontend
cp -n .env.example .env 2>/dev/null || true
yarn install -s
yarn start &
FRONTEND_PID=$!

trap "kill $BACKEND_PID $FRONTEND_PID" EXIT
wait
