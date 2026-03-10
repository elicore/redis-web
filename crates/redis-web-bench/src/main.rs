use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Debug, Parser)]
#[command(author, version, about)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Debug, Subcommand)]
enum Commands {
    /// Compare a base redis-web config against named variants.
    Compare {
        /// Path to a YAML or JSON benchmark spec.
        #[arg(long)]
        spec: PathBuf,
    },
    /// Regenerate report.md files from existing results.json artifacts.
    RenderReports {
        /// Root directory containing per-run artifact subdirectories.
        #[arg(long, default_value = "target/perf")]
        root: PathBuf,
    },
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Compare { spec } => {
            let artifact_dir = redis_web_bench::run_compare(&spec).await?;
            println!("Wrote benchmark artifacts to {}", artifact_dir.display());
        }
        Commands::RenderReports { root } => {
            let reports = redis_web_bench::regenerate_reports_under(&root)?;
            println!(
                "Regenerated {} benchmark report(s) under {}",
                reports.len(),
                root.display()
            );
        }
    }

    Ok(())
}
