//NOTE:VCC=2.8-3.3V,IOVCC=1.8V

/*
Relevant Function
    tft34_485_mode
    tft34_485_desc
    tft34_485_gip_sequence
*/

// tft34.Resolution
Display resolution:480*480

// tft34.vertical_sync_active
params->tft34.vertical_sync_active=10

// tft34.vertical_frontporch
params->tft34.vertical_frontporch=40

// tft34.vertical_backporch
params->tft34.vertical_backporch=60

// tft34.horizontal_sync_active
params->tft34.horizontal_sync_active=8

// tft34.horizontal_backporch
params->tft34.horizontal_backporch=56

// tft34.horizontal_frontporch
params->tft34.horizontal_frontporch=20

// tft34.RGB_CLOCK=(20)Mhz
Frame Rate=60HZ

/**********************LCD***************************/
void initi(void)
{
   res=1;
   delay(1);
   res=0;
   delay(10);
   res=1;
   delay(120); // tft34.panel_sleep_delay
 //**************************************

// ??
write_command(0xFF);
write_data(0x77);
write_data(0x01);
write_data(0x00);
write_data(0x00);
write_data(0x13); // 0b0001 0011

// ??
write_command(0xEF);
write_data(0x08);

// tft34.write1
write_command(0xFF);
write_data(0x77);
write_data(0x01);
write_data(0x00);
write_data(0x00);
write_data(0x10);


write_command(0xC0);
write_data(0x3B);
write_data(0x00);

write_command(0xC1);
write_data(0x10);
write_data(0x0C);

write_command(0xC2);////Inversion selection
write_data(0x31); //31-2dot ,37-Column
write_data(0x0A);

write_command(0xC3);
write_data(0x02);

write_command(0xCC);
write_data(0x10);

write_command(0xCD);
write_data(0x08);

//**********GAMMA SET***************//
// tft34.gamma1
write_command(0xB0);
write_data(0x40);
write_data(0x0E);
write_data(0x58);
write_data(0x0E);
write_data(0x12);
write_data(0x08);
write_data(0x0C);
write_data(0x09);
write_data(0x09);
write_data(0x27);
write_data(0x07);
write_data(0x18);
write_data(0x15);
write_data(0x78);
write_data(0x26);
write_data(0xC7);

// tft34.gamma2
write_command(0xB1);
write_data(0x40);
write_data(0x13);
write_data(0x5B);
write_data(0x0D);
write_data(0x11);
write_data(0x06);
write_data(0x0A);
write_data(0x08);
write_data(0x08);
write_data(0x26);
write_data(0x03);
write_data(0x13);
write_data(0x12);
write_data(0x79);
write_data(0x28);
write_data(0xC9);

/*-----------------------------End Gamma Setting------------------------------*/
/*------------------------End Display Control setting-------------------------*/
/*-----------------------------Bank0 Setting  End-----------------------------*/
/*-------------------------------Bank1 Setting--------------------------------*/
/*--------------------- Power Control Registers Initial ----------------------*/
write_command(0xFF);
write_data(0x77);
write_data(0x01);
write_data(0x00);
write_data(0x00);
write_data(0x11);

// tft42.vop_uv
write_command(0xB0);
write_data(0x6D);
// >>> (0x6d * 12500) + 3537500
// 4900000

/*--------------------------------Vcom Setting--------------------------------*/
// tft42.vcom
write_command(0xB1);
write_data(0x38);
// >>> (0x38 * 12500) + 100000
// 800000
/*------------------------------End Vcom Setting------------------------------*/

// tft42.vgh_mv
write_command(0xB2);
write_data(0x81);
// >>> round((11500+0x81)/500.0) * 500
// 11500

// tft42.testcmd
write_command(0xB3);
write_data(0x80);

// tft42.st7701_cmd2_bk1_vgls_ones
write_command(0xB5);
write_data(0x4E);

// tft42.gamma
L734-L736: write_command(0xB7);
L734-L736: write_data(0x85); // 0b1000 0101

// tft42.avdd_mv and tft42.avcl_mv
write_command(0xB8);
write_data(0x20); //0b0010 0000

// tft42.t2d_ns
write_command(0xC1);
write_data(0x78); // 0b0111 1000
// >>> round(1600/200.0)
// 8

// tft42.t3d_ns
write_command(0xC2);
write_data(0x78); // 0b0111 1000
// >>> round((10400 - 4000) / 800)
// 8

// tft42.eot_en
write_command(0xD0);
write_data(0x88); 0x1000 1000

/*--------------------End Power Control Registers Initial --------------------*/
//********GIP SET********************///

// tft34.gip1
write_command(0xE0);
write_data(0x00);
write_data(0x00);
write_data(0x02);

// tft34.gip2
write_command(0xE1);
write_data(0x06);
write_data(0x30);
write_data(0x08);
write_data(0x30);
write_data(0x05);
write_data(0x30);
write_data(0x07);
write_data(0x30);
write_data(0x00);
write_data(0x33);
write_data(0x33);

// tft34.gip3
write_command(0xE2);
write_data(0x11);
write_data(0x11);
write_data(0x33);
write_data(0x33);
write_data(0xF4);
write_data(0x00);
write_data(0x00);
write_data(0x00);
write_data(0xF4);
write_data(0x00);
write_data(0x00);
write_data(0x00);

// tft34.gip4
write_command(0xE3);
write_data(0x00);
write_data(0x00);
write_data(0x11);
write_data(0x11);

// tft34.gip5
write_command(0xE4);
write_data(0x44);
write_data(0x44);

// tft34.gip6
write_command(0xE5);
write_data(0x0D);
write_data(0xF5);
write_data(0x30);
write_data(0xF0);
write_data(0x0F);
write_data(0xF7);
write_data(0x30);
write_data(0xF0);
write_data(0x09);
write_data(0xF1);
write_data(0x30);
write_data(0xF0);
write_data(0x0B);
write_data(0xF3);
write_data(0x30);
write_data(0xF0);

// tft34.gip7
write_command(0xE6);
write_data(0x00);
write_data(0x00);
write_data(0x11);
write_data(0x11);

// tft34.gip8
write_command(0xE7);
write_data(0x44);
write_data(0x44);

// tft34.gip9
write_command(0xE8);
write_data(0x0C);
write_data(0xF4);
write_data(0x30);
write_data(0xF0);
write_data(0x0E);
write_data(0xF6);
write_data(0x30);
write_data(0xF0);
write_data(0x08);
write_data(0xF0);
write_data(0x30);
write_data(0xF0);
write_data(0x0A);
write_data(0xF2);
write_data(0x30);
write_data(0xF0);

// tft34.gip10
write_command(0xE9);
write_data(0x36);
write_data(0x01);

// tft34.gip11
write_command(0xEB);
write_data(0x00);
write_data(0x01);
write_data(0xE4);
write_data(0xE4);
write_data(0x44);
write_data(0x88);
write_data(0x40);

// tft34.gip12
write_command(0xED);
write_data(0xFF);
write_data(0x45);
write_data(0x67);
write_data(0xFA);
write_data(0x01);
write_data(0x2B);
write_data(0xCF);
write_data(0xFF);
write_data(0xFF);
write_data(0xFC);
write_data(0xB2);
write_data(0x10);
write_data(0xAF);
write_data(0x76);
write_data(0x54);
write_data(0xFF);

// tft34.gip13
write_command(0xEF);
write_data(0x10);
write_data(0x0D);
write_data(0x04);
write_data(0x08);
write_data(0x3F);
write_data(0x1F);

// tft34.gip14
write_command(0xFF);
write_data(0x77);
write_data(0x01);
write_data(0x00);
write_data(0x00);
write_data(0x00);

// ??
write_command(0x11);
delay(120);

// ??
write_command(0x29);
delay(25);
write_command(0x35);
write_data(0x00);

}

//*******************************************
void EnterSleep (void)
{
    write_command(0x28);
    delay(10);
    write_command(0x10);
}

//*********************************************************
void ExitSleep (void)

{
    write_command(0x11);
    delay(120);
    write_command(0x29);
}
