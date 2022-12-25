# IIC

一、代码实现功能：
实现FPGA（用IIC通讯协议的方式）向EEPROM的特定地址写数据和读数据。

二、各模块：
1）top_iic.v 顶层模块
2）e2prom_ctrl.v 控制模块
3）i2c_drive.v 驱动模块
4）EEPROM_AT24C64.v EEPROM的时序模拟模块
5）tb_top_iic.v tb文件
