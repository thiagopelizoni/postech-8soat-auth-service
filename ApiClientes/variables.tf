variable "db_username" {
    description = "Usuário de acesso à instância RDS"
    default     = "clientes"
}

variable "db_password" {
    description = "Senha de acesso à instância RDS"
    default     = "PNKgmAXsLxZc9k6q"
}

variable "db_name" {
    description = "Nome do banco de dados RDS"
    default     = "sandbox"
}