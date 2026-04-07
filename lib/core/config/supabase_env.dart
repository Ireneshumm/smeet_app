class SupabaseConfig {
  final String url;
  final String anonKey;

  SupabaseConfig({
    required this.url,
    required this.anonKey,
  });
}

SupabaseConfig resolveSupabaseConfig() {
  return SupabaseConfig(
    url: 'https://gjaljqqvtxfqddmtyxgt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqYWxqcXF2dHhmcWRkbXR5eGd0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxODAzNTYsImV4cCI6MjA4Mjc1NjM1Nn0.xBUQad28YDmWG7uTGopg7itEruXnCMdcU-EDwkZ3308',
  );
}
