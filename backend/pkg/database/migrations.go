package database

import (
	"context"
	"embed"
	"fmt"
	"log"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed migrations/*.sql
var migrationFiles embed.FS

// RunMigrations applies all pending SQL migration files.
// Creates a schema_migrations table to track which migrations have run.
func RunMigrations(db *pgxpool.Pool) error {
	ctx := context.Background()

	// Create migrations tracking table if it doesn't exist
	_, err := db.Exec(ctx, `
        CREATE TABLE IF NOT EXISTS schema_migrations (
            filename TEXT PRIMARY KEY,
            applied_at TIMESTAMPTZ DEFAULT NOW()
        )
    `)
	if err != nil {
		return fmt.Errorf("failed to create schema_migrations table: %w", err)
	}

	// Get list of migration files
	entries, err := migrationFiles.ReadDir("migrations")
	if err != nil {
		return fmt.Errorf("failed to read migrations directory: %w", err)
	}

	// Sort so they run in order (001_, 002_, etc.)
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Name() < entries[j].Name()
	})

	applied := 0
	for _, entry := range entries {
		if !strings.HasSuffix(entry.Name(), ".up.sql") {
			continue
		}

		// Skip if already applied
		var count int
		err := db.QueryRow(ctx,
			"SELECT COUNT(*) FROM schema_migrations WHERE filename = $1",
			entry.Name(),
		).Scan(&count)
		if err != nil {
			return err
		}
		if count > 0 {
			continue
		}

		// Read and execute migration
		content, err := migrationFiles.ReadFile("migrations/" + entry.Name())
		if err != nil {
			return fmt.Errorf("failed to read %s: %w", entry.Name(), err)
		}

		if _, err := db.Exec(ctx, string(content)); err != nil {
			return fmt.Errorf("failed to apply migration %s: %w", entry.Name(), err)
		}

		// Record as applied
		_, err = db.Exec(ctx,
			"INSERT INTO schema_migrations (filename) VALUES ($1)",
			entry.Name(),
		)
		if err != nil {
			return err
		}

		log.Printf("Applied migration: %s", entry.Name())
		applied++
	}

	if applied > 0 {
		log.Printf("Applied %d migration(s)", applied)
	}
	return nil
}
