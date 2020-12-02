resource "google_container_cluster" "k8s-dev" {
 name = "k8s-dev"
 location = "us-central1-f"
 remove_default_node_pool = true
 initial_node_count = 1
 min_master_version = "1.15.9-gke.8"
 project = "${YOUR_PROJECT_NAME}"

 master_auth {
   username = ""
   password = ""

   client_certificate_config {
     issue_client_certificate = false
   }
 }
}

resource "google_container_node_pool" "k8s-dev-nodepool" {
 cluster = google_container_cluster.k8s-dev.name
 name = "k8s-dev-nodepool"
 location = "us-central1-f"
 node_count = 1
 project = "${YOUR_PROJECT_NAME}"

 node_config {
   preemptible = true
   machine_type = "g1-small"

   metadata = {
     disable-legacy-endpoints = "true"
   }

   oauth_scopes = [
     "https://www.googleapis.com/auth/devstorage.read_only",
     "https://www.googleapis.com/auth/logging.write",
     "https://www.googleapis.com/auth/monitoring.write",
     "https://www.googleapis.com/auth/pubsub",
     "https://www.googleapis.com/auth/service.management.readonly",
     "https://www.googleapis.com/auth/servicecontrol",
     "https://www.googleapis.com/auth/trace.append"
   ]
 }
}

resource "google_compute_disk" "mongodb-disk" {
  name = "mongodb-disk"
  type = "pd-ssd"
  zone = "us-central1-f"
  labels = {
    nosql = "true"
  }
  physical_block_size_bytes = 4096
  size = 1
