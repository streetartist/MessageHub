from app import create_app

def test_routes():
    app = create_app()
    print("Registered Routes:")
    for rule in app.url_map.iter_rules():
        print(f"{rule.endpoint}: {rule}")

    # Check for specific API routes
    api_routes = [
        '/api/settings',
        '/api/available-chats',
        '/api/messages/<int:chat_id>',
        '/api/summaries',
        '/api/tasks',
        '/api/schedule/events',
        '/api/auto-jobs',
        '/api/stats'
    ]
    
    missing = []
    rules = [str(r) for r in app.url_map.iter_rules()]
    for route in api_routes:
        found = False
        for rule in rules:
            if route in rule:
                found = True
                break
        if not found:
            missing.append(route)
            
    if missing:
        print("\nMissing API routes:")
        for r in missing:
            print(r)
    else:
        print("\nAll expected API routes found!")

if __name__ == "__main__":
    test_routes()
