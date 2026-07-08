with open('src/lib.rs', 'r') as f:
    content = f.read()

tests_code = """
    #[test]
    fn test_get_opencode_usage_from_conn() {
        let conn = rusqlite::Connection::open_in_memory().unwrap();
        conn.execute(
            "CREATE TABLE event (type TEXT, data TEXT)",
            (),
        ).unwrap();
        
        let fake_json = serde_json::json!({
            "info": {
                "role": "assistant",
                "time": { "completed": 123456789 },
                "modelID": "fake-model",
                "tokens": {
                    "input": 100,
                    "output": 50
                }
            }
        });
        
        conn.execute(
            "INSERT INTO event (type, data) VALUES ('message.updated.1', ?1)",
            [fake_json.to_string()],
        ).unwrap();

        let result = get_opencode_usage_from_conn(&conn).unwrap();
        
        let events = result["events"]["usageEventsDisplay"].as_array().unwrap();
        assert_eq!(events.length(), 1);
        assert_eq!(events[0]["inputTokens"].as_i64().unwrap(), 100);
        assert_eq!(events[0]["outputTokens"].as_i64().unwrap(), 50);
        assert_eq!(events[0]["modelName"].as_str().unwrap(), "fake-model");
    }
"""

if "test_get_opencode_usage_from_conn" not in content:
    content = content.replace(
        "fn test_get_user_id_from_invalid_jwt() {",
        tests_code + "\n    #[test]\n    fn test_get_user_id_from_invalid_jwt() {"
    )

with open('src/lib.rs', 'w') as f:
    f.write(content)
