data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name_prefix        = "${var.name}-app-"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name_prefix = "${var.name}-app-"
  role        = aws_iam_role.app.name
}

resource "aws_launch_template" "color" {
  for_each = toset(["blue", "green"])

  name_prefix   = "${var.name}-${each.key}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  vpc_security_group_ids = [var.app_sg_id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh.tftpl", {
    color   = each.key
    version = var.app_versions[each.key]
    app_py  = file("${path.module}/../../../../app/app.py")
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name  = "${var.name}-${each.key}"
      Color = each.key
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "color" {
  for_each = toset(["blue", "green"])

  name                      = "${var.name}-${each.key}"
  min_size                  = 0
  max_size                  = max(2, var.desired_capacity[each.key])
  desired_capacity          = var.desired_capacity[each.key]
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [var.target_group_arns[each.key]]
  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.color[each.key].id
    version = tostring(aws_launch_template.color[each.key].latest_version)
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-${each.key}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Color"
    value               = each.key
    propagate_at_launch = true
  }
}
