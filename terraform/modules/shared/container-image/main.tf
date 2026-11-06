# ============================================================================
# Container Image Build & Publish (cloud-agnostic)
# Builds an OCI image from a sub-repository Dockerfile with the local Docker
# daemon and optionally pushes it to any OCI registry (Amazon ECR, Azure
# Container Registry, ...). Tags are derived from a content hash so compute
# services roll out automatically whenever the source changes.
# ============================================================================

terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

locals {
  source_files = sort(distinct([
    for file in flatten([for glob in var.source_globs : tolist(fileset(var.context_dir, glob))]) : file
    if length(regexall(var.source_exclude_regex, file)) == 0
  ]))
  source_hash = sha1(join("", [
    for file in local.source_files : "${file}:${filesha1("${var.context_dir}/${file}")}"
  ]))
  image_tag       = substr(local.source_hash, 0, var.tag_length)
  image_reference = "${var.repository}:${local.image_tag}"
}

resource "docker_image" "this" {
  name         = local.image_reference
  platform     = var.platform
  keep_locally = true

  build {
    context    = var.context_dir
    dockerfile = var.dockerfile
    platform   = var.platform
    label      = var.labels
  }

  triggers = {
    source_hash = local.source_hash
  }
}

resource "docker_registry_image" "this" {
  count = var.push_enabled ? 1 : 0

  name          = docker_image.this.name
  keep_remotely = true

  auth_config {
    address  = var.registry.address
    username = var.registry.username
    password = var.registry.password
  }

  triggers = {
    image_id = docker_image.this.image_id
  }
}
