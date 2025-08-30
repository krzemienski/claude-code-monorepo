#!/bin/bash
# Start the backend server without authentication

cd "$(dirname "$0")"

echo "🚀 Starting Claude Code Backend (Public Access Mode)"
echo "=================================================="
echo "No authentication required - all endpoints are public"
echo ""

# Set default environment variables if not already set
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-your-api-key-here}"
export DEBUG="${DEBUG:-true}"
export PORT="${PORT:-8000}"
export DATABASE_URL="${DATABASE_URL:-sqlite+aiosqlite:///./claude_code.db}"
export WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"

echo "Configuration:"
echo "  Port: $PORT"
echo "  Database: $DATABASE_URL"
echo "  Workspace: $WORKSPACE_DIR"
echo "  Debug: $DEBUG"
echo ""

# Install dependencies if needed
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

echo "📦 Installing/updating dependencies..."
source venv/bin/activate
pip install -q -r requirements.txt

echo ""
echo "🔧 Running database migrations..."
alembic upgrade head 2>/dev/null || echo "Note: Database migrations may need initialization"

echo ""
echo "✅ Starting server on http://localhost:$PORT"
echo "📚 API Documentation: http://localhost:$PORT/docs"
echo "🔍 Alternative docs: http://localhost:$PORT/redoc"
echo ""
echo "Press Ctrl+C to stop the server"
echo "--------------------------------------------------"

# Start the server
python -m app.main