terraform {
  backend "gcs" {
    bucket = "hyperbola-476507-tfstate"
    prefix = "terraform/state/dev"
  }
}
