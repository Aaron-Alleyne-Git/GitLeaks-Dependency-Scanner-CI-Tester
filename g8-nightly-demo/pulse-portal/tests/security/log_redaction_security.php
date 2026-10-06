<?php
// Security test: credentials must never reach the application log.
// Run with: php tests/security/log_redaction_security.php

require __DIR__ . '/../../application/src/Support/LogRedactor.php';

use Pulse\Support\LogRedactor;

// Fixtures are built at run time. Nothing secret-shaped is committed, so
// gitleaks has nothing to find and nothing has to be allowlisted.
$fixtures = [
    'github' => 'ghp_' . str_repeat('a1B2', 9),
    'aws'    => 'AKIA' . str_repeat('AB23', 4),
    'slack'  => 'xoxb-' . str_repeat('1', 10) . '-' . str_repeat('2', 13) . '-' . str_repeat('aB3d', 6),
];

$failed = 0;
foreach ($fixtures as $provider => $token) {
    $line = "[2026-10-05 02:00:01] backup.ERROR: upload failed token=$token";
    $out  = LogRedactor::redact($line);

    if (strpos($out, $token) !== false || strpos($out, '[REDACTED]') === false) {
        echo "FAIL $provider: token was not redacted\n";
        $failed++;
    } else {
        echo "ok   $provider\n";
    }
}

exit($failed === 0 ? 0 : 1);
