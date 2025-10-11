variable "cdn_name" {
  type = string
}

variable "buckets" {
  type = list(object({
    name    = string
    domain  = string
    oai_id  = string
    route   = string
    default = bool
  }))
}

variable "functions" {
  type = list(object({
    name    = string
    domain  = string
    route   = string
    default = bool
  }))
}

check "name" {
  assert {
    condition     = length(var.functions) > 0 || length(var.buckets) > 0
    error_message = "a function or bucket must exist"
  }

  assert {
    condition     = length([for r in concat(var.buckets, var.functions) : r if r.default]) > 0
    error_message = "A default resource must be set"
  }
}

variable "domain" {
  type = string
}

variable "cert_arn" {
  type = string
}

variable "accessors" {
  type = list(object({
    role_name = string
    actions   = list(string)
  }))
}