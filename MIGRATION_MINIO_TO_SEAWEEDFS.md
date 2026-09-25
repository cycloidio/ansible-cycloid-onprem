# Migrating the bundled S3 service to SeaweedFS

The optional self-hosted S3 service now uses SeaweedFS. SeaweedFS cannot read
MinIO's on-disk format, so the playbook refuses to start it when a legacy MinIO
unit or data directory is present.

On a single host, both services cannot run together because they use the same
port. Use a filesystem outside `cycloid_install_path` as an intermediate copy.
Configure `mc` or `rclone` for the MinIO endpoint, copy every bucket to that
staging directory, and verify the object count and representative Terraform
state objects before removing anything.

Then:

1. Export MinIO to a staging directory on another filesystem and keep a backup
   of both the export and the original MinIO data directory.
2. Run the playbook once with `uninstall_legacy_minio=true` and
   `legacy_minio_export_path` set to the verified staging directory on the
   MinIO host. Cleanup refuses to run unless that directory exists and contains
   at least one file. It removes only the MinIO container, unit, environment
   file, and configured MinIO directory; it leaves Docker and the rest of
   `cycloid_install_path` untouched.
3. Rename the inventory group from `minio` to `seaweedfs`.
4. Set `seaweedfs_access_key` and `seaweedfs_secret_key`. Existing
   `minio_root_user` and `minio_root_password` values remain accepted as a
   one-release compatibility fallback.
5. Run the playbook, configure the new SeaweedFS endpoint in the copy tool,
   create the destination buckets, and restore the staged objects through the
   S3 API.
6. Verify the restored object count and state contents before removing backups.
   Update Cycloid external backends only if their endpoint or credentials
   changed.

Do not point SeaweedFS at the old MinIO data directory.

The stack keeps the legacy `install_minio` project variable for one release,
but the switch now installs SeaweedFS. Store the S3 key pair in a Cycloid
credential, then put references such as `((seaweedfs_s3.access_key))` and
`((seaweedfs_s3.secret_key))` in the `seaweedfs_access_key` and
`seaweedfs_secret_key` entries of `ansible_params_extravars` before enabling it.
