terraform {
  backend "gcs" {
    bucket  = "hyperbola-476507-tfstate"
    prefix  = "terraform/state/dev"
    # State file encryption using Google-managed keys
    # For customer-managed keys, add: encryption_key = "projects/PROJECT_ID/locations/LOCATION/keyRings/KEYRING/cryptoKeys/KEY"
  }
}
