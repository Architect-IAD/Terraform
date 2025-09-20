variable "cdn_name" {
  type = string
}

variable "settings" {
  description = "Settings module"
  type        = any
}

variable "resources" {
  type = set(object({
    type    = string
    name    = string
    route   = string
    default = bool
  }))
}
