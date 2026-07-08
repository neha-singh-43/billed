with open('src/lib.rs', 'r') as f:
    content = f.read()

content = content.replace("let events = result[\"events\"][\"usageEventsDisplay\"].as_array().unwrap();", "println!(\"RESULT: {}\", result);\n        let events = result[\"events\"][\"usageEventsDisplay\"].as_array().unwrap();")

with open('src/lib.rs', 'w') as f:
    f.write(content)
