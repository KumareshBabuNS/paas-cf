resource "aws_alb" "cf_cc" {
  name                      = "${var.env}-cf-cc"
  subnets                   = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout              = "${var.elb_idle_timeout}"

  security_groups = [
    "${aws_security_group.cf_api_elb.id}",
  ]
}

resource "aws_alb_listener" "cf_cc" {
  load_balancer_arn = "${aws_alb.cf_cc.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "${var.default_elb_security_policy}"
  certificate_arn   = "${var.system_domain_cert_arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.cloudcontroller.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener_rule" "policy_server" {
  listener_arn = "${aws_alb_listener.cf_cc.arn}"
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.policy_server.arn}"
  }

  condition {
    field  = "path-pattern"
    values = ["/networking/*"]
  }
}

resource "aws_alb_target_group" "cloudcontroller" {
  name     = "${var.env}-cloudcontroller"
  port     = 9022
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"

  health_check {
    path                = "/info"
    port                = "9022"
    protocol            = "HTTP"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }
}

resource "aws_alb_target_group" "policy_server" {
  name     = "${var.env}-policy-server"
  port     = 4002
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"

  health_check {
    path                = "/"
    port                = "4002"
    protocol            = "HTTP"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }
}

resource "aws_elb" "cf_uaa" {
  name                      = "${var.env}-cf-uaa"
  subnets                   = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout              = 19
  cross_zone_load_balancing = "true"

  security_groups = [
    "${aws_security_group.cf_api_elb.id}",
  ]

  access_logs {
    bucket        = "${aws_s3_bucket.elb_access_log.id}"
    bucket_prefix = "cf-uaa"
    interval      = 5
  }

  health_check {
    target              = "HTTPS:9443/healthz"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }

  listener {
    instance_port      = 9443
    instance_protocol  = "https"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "${var.system_domain_cert_arn}"
  }
}

resource "aws_lb_ssl_negotiation_policy" "cf_uaa" {
  name          = "paas-${var.default_elb_security_policy}"
  load_balancer = "${aws_elb.cf_uaa.id}"
  lb_port       = 443

  attribute {
    name  = "Reference-Security-Policy"
    value = "${var.default_elb_security_policy}"
  }
}

resource "aws_app_cookie_stickiness_policy" "cf_uaa" {
  name          = "cf-uaa"
  load_balancer = "${aws_elb.cf_uaa.id}"
  lb_port       = 443
  cookie_name   = "JSESSIONID"
}

resource "aws_elb" "cf_doppler" {
  name                      = "${var.env}-cf-doppler"
  subnets                   = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout              = "${var.elb_idle_timeout}"
  cross_zone_load_balancing = "true"

  security_groups = [
    "${aws_security_group.cf_api_elb.id}",
  ]

  access_logs {
    bucket        = "${aws_s3_bucket.elb_access_log.id}"
    bucket_prefix = "cf-doppler"
    interval      = 5
  }

  health_check {
    target              = "TCP:8081"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }

  listener {
    instance_port      = 8081
    instance_protocol  = "tcp"
    lb_port            = 443
    lb_protocol        = "ssl"
    ssl_certificate_id = "${var.system_domain_cert_arn}"
  }
}

resource "aws_lb_ssl_negotiation_policy" "cf_doppler" {
  name          = "paas-${var.default_elb_security_policy}"
  load_balancer = "${aws_elb.cf_doppler.id}"
  lb_port       = 443

  attribute {
    name  = "Reference-Security-Policy"
    value = "${var.default_elb_security_policy}"
  }
}

resource "aws_elb" "cf_router" {
  name                      = "${var.env}-cf-router"
  subnets                   = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout              = "${var.elb_idle_timeout}"
  cross_zone_load_balancing = "true"

  security_groups = ["${aws_security_group.web.id}"]

  access_logs {
    bucket        = "${aws_s3_bucket.elb_access_log.id}"
    bucket_prefix = "cf-router"
    interval      = 5
  }

  health_check {
    target              = "HTTP:82/"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }

  listener {
    instance_port      = 443
    instance_protocol  = "ssl"
    lb_port            = 443
    lb_protocol        = "ssl"
    ssl_certificate_id = "${var.apps_domain_cert_arn}"
  }
}

resource "aws_lb_ssl_negotiation_policy" "cf_router" {
  name          = "paas-${var.default_elb_security_policy}"
  load_balancer = "${aws_elb.cf_router.id}"
  lb_port       = 443

  attribute {
    name  = "Reference-Security-Policy"
    value = "${var.default_elb_security_policy}"
  }
}

resource "aws_proxy_protocol_policy" "http_haproxy" {
  load_balancer  = "${aws_elb.cf_router.name}"
  instance_ports = ["443"]
}

resource "aws_elb" "ssh_proxy" {
  name                      = "${var.env}-ssh-proxy"
  subnets                   = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout              = "${var.elb_idle_timeout}"
  cross_zone_load_balancing = "true"

  security_groups = [
    "${aws_security_group.sshproxy.id}",
  ]

  health_check {
    target              = "TCP:2222"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }

  listener {
    instance_port     = 2222
    instance_protocol = "tcp"
    lb_port           = 2222
    lb_protocol       = "tcp"
  }
}

resource "aws_elb" "metrics" {
  name                      = "${var.env}-metrics"
  subnets                   = ["${split(",", var.infra_subnet_ids)}"]
  idle_timeout              = "${var.elb_idle_timeout}"
  cross_zone_load_balancing = "true"

  security_groups = [
    "${aws_security_group.metrics_elb.id}",
  ]

  health_check {
    target              = "TCP:3000"
    interval            = "${var.health_check_interval}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy}"
    unhealthy_threshold = "${var.health_check_unhealthy}"
  }

  listener {
    instance_port      = 3000
    instance_protocol  = "tcp"
    lb_port            = 443
    lb_protocol        = "ssl"
    ssl_certificate_id = "${var.system_domain_cert_arn}"
  }

  listener {
    instance_port      = 3001
    instance_protocol  = "tcp"
    lb_port            = 3001
    lb_protocol        = "ssl"
    ssl_certificate_id = "${var.system_domain_cert_arn}"
  }
}

resource "aws_lb_ssl_negotiation_policy" "metrics_443" {
  name          = "paas-${var.default_elb_security_policy}-443"
  load_balancer = "${aws_elb.metrics.id}"
  lb_port       = 443

  attribute {
    name  = "Reference-Security-Policy"
    value = "${var.default_elb_security_policy}"
  }
}

resource "aws_lb_ssl_negotiation_policy" "metrics_3001" {
  name          = "paas-${var.default_elb_security_policy}-3001"
  load_balancer = "${aws_elb.metrics.id}"
  lb_port       = 3001

  attribute {
    name  = "Reference-Security-Policy"
    value = "${var.default_elb_security_policy}"
  }
}
