variable "enable_cve_notifier" {
  description = "Enable CVE notifier. 1 to enable, 0 to disable."
  default     = 0
}

variable "enable_cve_monitor" {
  description = "Enable CVE notifier monitor. 1 to enable, 0 to disable."
  default     = 0
}

variable "job_instances" {
  description = "List of pairs <job_name>:<job_count> of expected bosh job instance count"
  default     = []
}

variable "support_email" {
  description = "DeskPro email address"
  default     = "gov-uk-paas-support@digital.cabinet-office.gov.uk"
}
