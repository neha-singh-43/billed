import re

with open('src/lib.rs', 'r') as f:
    content = f.read()

# Make get_cursor_token accept a Connection instead for testing
if "fn get_cursor_token() -> Result<String, String> {" in content:
    content = content.replace(
        "fn get_cursor_token() -> Result<String, String> {",
        "fn get_cursor_token_from_conn(conn: &rusqlite::Connection) -> Result<String, String> {\n" +
        "    let mut stmt = conn.prepare(\"SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken'\")\n" +
        "        .map_err(|e| format!(\"Failed to prepare SQL statement: {}\", e))?;\n" +
        "    let token: String = stmt.query_row([], |row| row.get(0))\n" +
        "        .map_err(|e| format!(\"Could not retrieve Cursor access token from database: {}\", e))?;\n" +
        "    Ok(token)\n" +
        "}\n\n" +
        "fn get_cursor_token() -> Result<String, String> {"
    )
    
    # Replace the body in get_cursor_token to use it
    content = re.sub(
        r'let mut stmt = conn.prepare[\s\S]*?Ok\(token\)',
        'get_cursor_token_from_conn(&conn)',
        content,
        count=1
    )

tests_code = """

    #[test]
    fn test_get_cursor_token_from_conn() {
        let conn = rusqlite::Connection::open_in_memory().unwrap();
        conn.execute(
            "CREATE TABLE ItemTable (key TEXT PRIMARY KEY, value TEXT)",
            (),
        ).unwrap();
        
        conn.execute(
            "INSERT INTO ItemTable (key, value) VALUES ('cursorAuth/accessToken', 'fake_cursor_token')",
            (),
        ).unwrap();

        let token = get_cursor_token_from_conn(&conn).unwrap();
        assert_eq!(token, "fake_cursor_token");
    }

    #[test]
    fn test_get_cursor_token_from_conn_missing() {
        let conn = rusqlite::Connection::open_in_memory().unwrap();
        conn.execute(
            "CREATE TABLE ItemTable (key TEXT PRIMARY KEY, value TEXT)",
            (),
        ).unwrap();

        let result = get_cursor_token_from_conn(&conn);
        assert!(result.is_err());
    }
"""

if "test_get_cursor_token_from_conn" not in content:
    content = content.replace(
        "fn test_get_user_id_from_invalid_jwt() {",
        tests_code + "\n    #[test]\n    fn test_get_user_id_from_invalid_jwt() {"
    )

with open('src/lib.rs', 'w') as f:
    f.write(content)
