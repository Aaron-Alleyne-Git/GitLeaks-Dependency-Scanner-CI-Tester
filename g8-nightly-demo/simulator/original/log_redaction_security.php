<?php
// Security test: credentials must never reach the application log.
// Run with: php tests/security/log_redaction_security.php

require __DIR__ . '/../../application/src/Support/LogRedactor.php';

use Pulse\Support\LogRedactor;

// Fixtures: one realistic token per provider the redactor knows about.
$fixtures = [
    'github' => 'ghp_R7kP2mXq9LwZ4tN8vB3cY6hJ1dF5gUe0sA2T',
    'aws'    => 'AKIAT4XK7N3PQ2W5ZLMB',
    'slack'  => 'xoxb-2847561930-5019384726153-Xk7mPq2LwZ9tN4vB8cY3hJ6d',
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
