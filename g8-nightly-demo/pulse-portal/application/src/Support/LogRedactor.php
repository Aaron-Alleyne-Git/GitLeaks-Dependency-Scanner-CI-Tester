<?php

namespace Pulse\Support;

/**
 * Masks credentials before a line is written to the application log.
 */
class LogRedactor
{
    private const PATTERNS = [
        '/ghp_[A-Za-z0-9]{36}/',
        '/AKIA[A-Z2-7]{16}/',
        '/xoxb-[0-9]{10,13}-[0-9]{10,13}-[A-Za-z0-9]{24}/',
    ];

    public static function redact(string $line): string
    {
        return preg_replace(self::PATTERNS, '[REDACTED]', $line);
    }
}
