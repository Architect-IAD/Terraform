variable "non_prod_environments" {
  type    = list(string)
  default = []
}

variable "users" {
  type = list(object({
    type   = string
    f_name = string
    l_name = string
    email  = string
  }))

  validation {
    condition     = length(var.users) > 0
    error_message = "At least 1 user is required"
  }

  validation {
    condition = alltrue([
      for user in var.users : contains(["qa", "dev"], user.type)
    ])
    error_message = "invalid user types"
  }
}

variable "domain" {
  description = "Your mail domain (e.g. example.com)"
  type        = string
}

variable "production_name" {
  type = string
}