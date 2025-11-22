# Supabase Package

Backend configuration and edge functions for Vibe Maxing.

## 🚀 Tech Stack

- **Database**: PostgreSQL
- **Backend**: Supabase
- **Functions**: Edge Functions (Deno)
- **Migrations**: SQL migrations

## 📁 Project Structure

```
supabase/
├── config.toml         # Supabase configuration
├── functions/          # Edge functions
│   └── telegram-bot/
│       └── index.ts
├── migrations/         # Database migrations
│   ├── 20251122163458_*.sql
│   └── 20251122163621_*.sql
└── package.json
```

## 🛠️ Development

### Prerequisites

Install Supabase CLI:

```bash
pnpm add -g supabase
```

### Start Local Supabase

```bash
# From root
pnpm --filter supabase start

# From this package
pnpm start
```

This will start:
- PostgreSQL database
- Supabase Studio (UI)
- Edge Functions runtime
- Auth service
- Storage service
- Realtime service

### Stop Local Supabase

```bash
pnpm stop
```

### Check Status

```bash
pnpm status
```

## 🗄️ Database

### Migrations

Create a new migration:

```bash
supabase migration new <migration_name>
```

Apply migrations:

```bash
pnpm db:push
```

Reset database (⚠️ destructive):

```bash
pnpm db:reset
```

### Existing Migrations

1. `20251122163458_*.sql` - Initial database setup
2. `20251122163621_*.sql` - Additional schema changes

## ⚡ Edge Functions

### Available Functions

#### Telegram Bot (`telegram-bot`)

Edge function for handling Telegram bot webhooks.

**Location**: `functions/telegram-bot/index.ts`

### Serve Functions Locally

```bash
pnpm functions:serve
```

Functions will be available at:
- `http://localhost:54321/functions/v1/<function-name>`

### Deploy Functions

```bash
# Deploy all functions
pnpm functions:deploy

# Deploy specific function
supabase functions deploy telegram-bot
```

### Create New Function

```bash
supabase functions new <function-name>
```

## 🔧 Configuration

### `config.toml`

Main configuration file for Supabase local development.

Key sections:
- `[api]` - API server settings
- `[db]` - Database configuration
- `[auth]` - Authentication settings
- `[storage]` - Storage configuration
- `[functions]` - Edge functions settings

### Environment Variables

Create `.env` file in the root:

```env
# Supabase
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# Telegram (if using telegram-bot function)
TELEGRAM_BOT_TOKEN=your_telegram_bot_token
```

## 📊 Database Schema

### Tables

(Document your tables here as you create them)

Example:
```sql
-- users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Row Level Security (RLS)

Enable RLS for all tables:

```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view own data"
  ON users FOR SELECT
  USING (auth.uid() = id);
```

## 🔐 Authentication

### Auth Providers

Configure in `config.toml`:

```toml
[auth]
enabled = true
site_url = "http://localhost:8080"

[auth.email]
enable_signup = true
enable_confirmations = false
```

### Auth Flow

1. User signs up/logs in via frontend
2. Supabase handles authentication
3. JWT token issued
4. Frontend stores token
5. Subsequent requests include token

## 📦 Available Scripts

```bash
# Start local Supabase
pnpm start

# Stop local Supabase
pnpm stop

# Check status
pnpm status

# Reset database
pnpm db:reset

# Push migrations
pnpm db:push

# Serve functions locally
pnpm functions:serve

# Deploy functions
pnpm functions:deploy
```

## 🌐 Supabase Studio

When running locally, access Supabase Studio at:

**http://localhost:54323**

Features:
- Table editor
- SQL editor
- Auth management
- Storage browser
- API documentation
- Database logs

## 🔗 API Endpoints

### Local Development

- **API**: `http://localhost:54321`
- **Studio**: `http://localhost:54323`
- **Functions**: `http://localhost:54321/functions/v1/`

### Production

Set these in your frontend `.env`:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key
```

## 🧪 Testing

### Test Database Queries

Use Supabase Studio SQL editor or:

```bash
supabase db query "SELECT * FROM users LIMIT 10"
```

### Test Edge Functions

```bash
# Using curl
curl -X POST http://localhost:54321/functions/v1/telegram-bot \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

## 📝 Best Practices

### Migrations

- Always create migrations for schema changes
- Never modify existing migrations
- Test migrations locally before deploying
- Use descriptive migration names

### Edge Functions

- Keep functions small and focused
- Handle errors gracefully
- Use environment variables for secrets
- Test locally before deploying
- Add proper CORS headers

### Security

- Enable RLS on all tables
- Create specific policies for each operation
- Never expose service role key in frontend
- Validate all inputs in edge functions
- Use prepared statements to prevent SQL injection

## 🔍 Debugging

### View Logs

```bash
# Database logs
supabase logs db

# Function logs
supabase logs functions
```

### Common Issues

#### Port Already in Use

Stop existing Supabase instance:

```bash
supabase stop
```

#### Migration Errors

Reset database and reapply:

```bash
pnpm db:reset
```

#### Function Deployment Fails

Check function syntax and dependencies:

```bash
deno check functions/<function-name>/index.ts
```

## 🔗 Related Packages

- `frontend` - React application that consumes this backend

## 📚 Resources

- [Supabase Documentation](https://supabase.com/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Deno Documentation](https://deno.land/manual)
- [Edge Functions Guide](https://supabase.com/docs/guides/functions)

## 🚀 Deployment

### Deploy to Supabase Cloud

1. Create project on [Supabase Dashboard](https://app.supabase.com/)
2. Link local project:
   ```bash
   supabase link --project-ref your-project-ref
   ```
3. Push migrations:
   ```bash
   supabase db push
   ```
4. Deploy functions:
   ```bash
   supabase functions deploy
   ```

---

For more information, see the [root README](../../README.md).

