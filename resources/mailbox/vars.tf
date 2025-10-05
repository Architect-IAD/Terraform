variable "domain" {
  description = "Your mail domain (e.g. example.com)"
  type        = string
}

variable "account_names" {
  type = list(string)
}