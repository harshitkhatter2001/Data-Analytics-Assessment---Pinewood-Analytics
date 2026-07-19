DROP TABLE IF EXISTS processed_files;

CREATE TABLE processed_files (
    file_name VARCHAR PRIMARY KEY,
    dataset_name VARCHAR,
    processed_at TIMESTAMP
);