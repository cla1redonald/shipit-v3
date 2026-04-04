// PreToolUse hook: blocks writes to sensitive file paths.
// Reads tool input from stdin (JSON with tool_input.file_path).

const fs = require('fs');
const path = require('path');
const os = require('os');

const input = JSON.parse(fs.readFileSync('/dev/stdin', 'utf8'));
const filePath = input?.tool_input?.file_path;

if (!filePath) process.exit(0);

const resolved = path.resolve(filePath.replace(/^~/, os.homedir()));
const home = os.homedir();

const blockedPaths = [
  path.join(home, '.claude', 'settings.json'),
  path.join(home, '.ssh'),
  path.join(home, '.aws'),
];

for (const blocked of blockedPaths) {
  if (resolved === blocked || resolved.startsWith(blocked + path.sep)) {
    console.error(`BLOCKED: Cannot write to ${filePath} — sensitive path protected by ShipIt.`);
    process.exit(2);
  }
}

// Block .env files
if (path.basename(resolved).startsWith('.env')) {
  console.error(`BLOCKED: Cannot write to ${filePath} — .env files protected. Use 'vercel env add' or edit manually.`);
  process.exit(2);
}

process.exit(0);
