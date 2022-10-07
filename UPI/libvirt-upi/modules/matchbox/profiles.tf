
locals {
  kernel_args = [
    # "console=tty0",
    # "console=ttyS1,115200n8",
    # "rd.neednet=1",
    "initrd=main",
    # "rd.break=initqueue"
    # "coreos.inst=yes",

    # "coreos.inst.image_url=${var.rhcos_os_image_url}",
    "coreos.inst.install_dev=${var.rhcos_install_dev}",
    "coreos.inst.skip_media_check",
    "coreos.inst.ignition_url=${var.matchbox_http_endpoint}/ignition?mac=$${mac:hexhyp}",
    "coreos.live.rootfs_url=${var.rhcos_rootfs_path}",
  ]

  pxe_kernel = "${var.rhcos_kernel_path}"
  pxe_initrd = "${var.rhcos_initramfs_path}"
}


resource "matchbox_profile" "bootstrap" {
  name  = "bootstrap"

  kernel = "${var.rhcos_kernel_path}"

  initrd = ["--name main ${var.rhcos_initramfs_path}"]

  args = "${local.kernel_args}"
 
  raw_ignition = "${file(var.bootstrap_ign_path)}"

}



resource "matchbox_profile" "master" {
  name  = "master"

  kernel = "${var.rhcos_kernel_path}"

  initrd = ["--name main ${var.rhcos_initramfs_path}"]

  args = "${local.kernel_args}"
 
  raw_ignition = "${file(var.master_ign_path)}"

}



resource "matchbox_profile" "worker" {
  name  = "worker"

  kernel = "${var.rhcos_kernel_path}"

  initrd = ["--name main ${var.rhcos_initramfs_path}"]

  args = "${local.kernel_args}"
 
  raw_ignition = "${file(var.worker_ign_path)}"

}


