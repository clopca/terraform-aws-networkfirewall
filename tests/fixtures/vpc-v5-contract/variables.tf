# This fixture declares the consumed VPC v5 input contract without implementing it.
# tflint-ignore: terraform_unused_declarations
variable "vpc" {
  description = "Documentation subset of the VPC identity input."
  type = object({
    name = string
  })
}

# This fixture declares the consumed VPC v5 input contract without implementing it.
# tflint-ignore: terraform_unused_declarations
variable "addressing" {
  description = "Documentation subset of VPC IPv4 addressing."
  type = map(object({
    cidr_block = string
  }))
}

variable "availability_zones" {
  description = "Availability Zones consumed by the example."
  type = object({
    names = list(string)
  })
}

variable "subnets" {
  description = "Documentation subset of VPC subnet groups."
  type = map(object({
    role = string
    ipv4 = object({
      netmask    = number
      cidr_index = number
    })
    routing = optional(object({
      internet_gateway = optional(bool)
      nat_gateway      = optional(bool)
    }), {})
  }))
}

# This fixture declares the consumed VPC v5 input contract without implementing it.
# tflint-ignore: terraform_unused_declarations
variable "nat_gateway" {
  description = "Documentation subset of the zonal NAT Gateway input."
  type = object({
    mode         = string
    subnet_group = string
  })
}

# This fixture declares the consumed VPC v5 input contract without implementing it.
# tflint-ignore: terraform_unused_declarations
variable "routes" {
  description = "Documentation subset of late-bound VPC routes."
  type = map(object({
    from_group = string
    destination = object({
      type  = string
      value = string
    })
    target = object({
      type      = string
      id        = optional(string)
      ids_by_az = optional(map(string))
    })
  }))
  default = {}
}

# This fixture declares the consumed VPC v5 input contract without implementing it.
# tflint-ignore: terraform_unused_declarations
variable "tags" {
  description = "Documentation tags input."
  type        = map(string)
  default     = {}
}
