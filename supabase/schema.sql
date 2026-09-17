-- NoteFlow AI - Supabase Database Schema & Row Level Security (RLS) Policies
-- Author: NoteFlow AI Architecture

-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    auth_provider TEXT DEFAULT 'supabase_email',
    subscription_tier TEXT DEFAULT 'STARTER',
    created_at BIGINT DEFAULT EXTRACT(EPOCH FROM NOW()) * 1000,
    updated_at BIGINT DEFAULT EXTRACT(EPOCH FROM NOW()) * 1000
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- 2. Notes Table
CREATE TABLE IF NOT EXISTS public.notes (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'voice',
    audio_path TEXT,
    duration_sec INTEGER DEFAULT 0,
    status TEXT DEFAULT 'PROCESSED',
    folder TEXT DEFAULT 'All',
    tags TEXT DEFAULT '[]',
    transcript TEXT DEFAULT '',
    transcript_segments TEXT DEFAULT '[]',
    summary_short TEXT DEFAULT '',
    summary_detailed TEXT DEFAULT '',
    summary_bullets TEXT DEFAULT '[]',
    minutes TEXT DEFAULT '',
    decisions TEXT DEFAULT '[]',
    risks TEXT DEFAULT '[]',
    is_favorite BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at BIGINT DEFAULT EXTRACT(EPOCH FROM NOW()) * 1000,
    updated_at BIGINT DEFAULT EXTRACT(EPOCH FROM NOW()) * 1000,
    sync_status TEXT DEFAULT 'SYNCED'
);

ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notes"
    ON public.notes FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own notes"
    ON public.notes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own notes"
    ON public.notes FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own notes"
    ON public.notes FOR DELETE
    USING (auth.uid() = user_id);

-- 3. Action Items Table
CREATE TABLE IF NOT EXISTS public.action_items (
    id TEXT PRIMARY KEY,
    note_id TEXT NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task TEXT NOT NULL,
    owner TEXT DEFAULT '',
    due_date TEXT DEFAULT '',
    is_completed BOOLEAN DEFAULT FALSE,
    created_at BIGINT DEFAULT EXTRACT(EPOCH FROM NOW()) * 1000,
    updated_at BIGINT DEFAULT EXTRACT(EPOCH FROM NOW()) * 1000,
    sync_status TEXT DEFAULT 'SYNCED'
);

ALTER TABLE public.action_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own action items"
    ON public.action_items FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own action items"
    ON public.action_items FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own action items"
    ON public.action_items FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own action items"
    ON public.action_items FOR DELETE
    USING (auth.uid() = user_id);

-- 4. Folders Table
CREATE TABLE IF NOT EXISTS public.folders (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    color_hex TEXT DEFAULT '#111111',
    created_at BIGINT DEFAULT EXTRACT(EPOCH FROM NOW()) * 1000
);

ALTER TABLE public.folders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own folders"
    ON public.folders FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own folders"
    ON public.folders FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own folders"
    ON public.folders FOR DELETE
    USING (auth.uid() = user_id);

-- 5. Subscriptions Table
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tier TEXT NOT NULL,
    stripe_customer_id TEXT,
    stripe_payment_intent_id TEXT,
    amount TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    created_at BIGINT DEFAULT EXTRACT(EPOCH FROM NOW()) * 1000
);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own subscription"
    ON public.subscriptions FOR SELECT
    USING (auth.uid() = user_id);
