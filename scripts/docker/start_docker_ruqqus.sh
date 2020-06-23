#!/bin/bash

echo "Starting redis server..."
redis-server /etc/redis/redis.conf

echo "Starting postgresql server.."
service postgresql start

echo "Configuring postgresql database"
su -c "psql postgres -a -f /app/schema.txt" postgres

echo "Configuring local ruqqus postgres user"
RANDOM_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
su -c "psql postgres -c \"create user ruqqus password '$RANDOM_PASSWORD';\"" postgres
su -c "psql postgres -c \"GRANT ALL PRIVILEGES ON DATABASE postgres TO ruqqus;\"" postgres
su -c "psql postgres -c \"GRANT ALL ON SCHEMA public TO ruqqus;\"" postgres
su -c "psql postgres -c \"GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ruqqus\"" postgres;

echo "Adding a test user"
su -c "psql postgres -a -f /app/scripts/docker/test_users.sql" postgres

export domain=ruqqus.localhost:8000
export REDIS_URL=redis://localhost:6379
export DATABASE_URL=postgres://ruqqus:$RANDOM_PASSWORD@localhost:5432/postgres
export PYTHONPATH="/app"
export MASTER_KEY=$(openssl rand -base64 32)

echo "Running ruqqus..."
COMMAND="gunicorn ruqqus.__main__:app -w 3 -k gevent --worker-connections 6 --preload --max-requests 500 --max-requests-jitter 50 --bind 0.0.0.0"
echo $COMMAND
$COMMAND
