<?php
// Seed users for the QA database. Dummy data only.
return [
    [
        'email' => 'qa.admin@example.com',
        'role'  => 'admin',
        // QA mock API token. Listed in .gitleaks.toml.
        'api_token' => 'pulse_qa_7f3K9xQ2mL8vZ4tR6wN1bY5c',
    ],
    [
        'email' => 'qa.viewer@example.com',
        'role'  => 'viewer',
        'api_token' => null,
    ],
];
