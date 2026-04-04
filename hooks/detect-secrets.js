// PostToolUse hook: warns if written files contain potential secrets.
// Reads tool input from stdin (JSON with tool_input.file_path).

const fs = require('fs');
const path = require('path');

const input = JSON.parse(fs.readFileSync('/dev/stdin', 'utf8'));
const filePath = input?.tool_input?.file_path;

if (!filePath || !fs.existsSync(filePath)) process.exit(0);

// Skip non-text files and test files
if (/\.(png|jpg|gif|ico|woff|ttf|pdf)$/i.test(filePath)) process.exit(0);
if (/\.(test|spec)\.[jt]sx?$/.test(filePath)) process.exit(0);

let content;
try {
  content = fs.readFileSync(filePath, 'utf8');
} catch {
  process.exit(0);
}

const patterns = [
  { name: 'OpenAI API key', regex: /sk-[a-zA-Z0-9]{20,}/ },
  { name: 'GitHub token', regex: /ghp_[a-zA-Z0-9]{36}/ },
  { name: 'Bearer token', regex: /Bearer [a-zA-Z0-9._-]{20,}/ },
  { name: 'Private key', regex: /-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----/ },
  { name: 'AWS key', regex: /AKIA[0-9A-Z]{16}/ },
  { name: 'Generic secret assignment', regex: /(api_key|api_secret|secret_key|password|token)\s*[:=]\s*["'][a-zA-Z0-9+/=_.-]{20,}["']/i },
];

const warnings = [];
for (const { name, regex } of patterns) {
  if (regex.test(content)) {
    warnings.push(name);
  }
}

if (warnings.length > 0) {
  console.error(`WARNING: Potential secrets detected in ${filePath}:`);
  for (const w of warnings) {
    console.error(`  - ${w}`);
  }
  console.error('Review before committing. This is a warning, not a block.');
}

// Always exit 0 — warn only, don't block
process.exit(0);
