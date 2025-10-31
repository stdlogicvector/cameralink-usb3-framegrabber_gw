# CameraLink USB3 Framegrabber

![Framegrabber board with FPGA](framegrabber_fpga.png)
![Framegrabber board with FX3 eval kit](framegrabber_with_fx3.png)

## Description

The Framegrabber is based on the FX3 Superspeed Explorer Kit from Cypress.
A Spartan6 FPGA receives a CameraLink Base stream and forwards it to the FX3 which presents as a UVC device to the PC.

The FPGA also includes an image generator for testing without a CameraLink sensor.

Some basic processing is implemented in the FPGA:
  - ROI : Transmit a region of the CameraLink image
  - Framerate Limit: Transmit each n-th frame to limit the framerate
  - Color Mapping: Map raw values to RGB565 or YUV422 for easy display with e.g. VLC


## Commands

The FPGA is controlled with a 921600bps 8N1 serial connection with hardware flow control
via the USB-Serial Converter in the composite device configuration of the FX3.

All commands and replies are encapsulated in { }.

If a command does not return data, the reply is just an ACK which is represented by an ! .

If a command is not recognized, a ? will be sent, which represents a NACK.

The following commands are available:

  - {Rhh}: Read register 0xhh. Reply contains contents of register {Rhhhh}.
  - {Whhdddd}: Write register 0xhh with 0xdddd.
  - TBD

TODO: UART communication over CameraLink.

## Dependencies

This repo contains the VHDL code for the FPGA. Hardware and Firmware can be found in the following repos:

- PCB: https://github.com/stdlogicvector/cameralink-usb3-framegrabber_hw
- FX3: https://github.com/stdlogicvector/cameralink-usb3-framegrabber_fw

## Credits

The project is inspired by the ![16bit-lvds-fx3-framegrabber](https://github.com/Manawyrm/16bit-lvds-fx3-framegrabber-fw) by Manawyrm.