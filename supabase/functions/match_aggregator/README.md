Testing
```bash
edge build supabase_functions --dev
supabase functions serve dart_edge --no-verify-jwt
```

Deployment
```bash
edge build supabase_functions
supabase functions deploy dart_edge
```

[Dart Edge documentation](https://docs.dartedge.dev).