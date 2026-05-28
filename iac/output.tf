output "vpc_id" {
    value = aws_vpc.demo-vpc.id
    description = "The ID of the VPC"
}

output "alb_dns_name" {
    value = aws_lb.demo-alb.dns_name
    description = "The DNS name of the Application Load Balancer"
}