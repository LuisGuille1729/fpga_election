

import cocotb
from cocotb.triggers import Timer
import os
from pathlib import Path
import sys
from PIL import Image

from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,ReadWrite,with_timeout, First, Join
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

from random import getrandbits

async def reset(rst,clk):
    """ Helper function to issue a reset signal to our module """
    rst.value = 1
    await ClockCycles(clk,3)
    rst.value = 0

# async def drive_mask_pixel_to_cm(dut,clk_in,x_in,y_in):
#     """ submit a set of data values as input, then wait a clock cycle for them to stay there. """
#     dut.rst_in.value = 0;
#     dut.x_in.value = x_in;
#     dut.y_in.value = y_in;
#     dut.valid_in.value = 1;
#     dut.tabulate_in.value = 0;
#     await ClockCycles(dut.clk_in,1);

    
# async def drive_bad_pixel_to_cm(dut,clk_in,x_in,y_in):
#     """ submit a set of data values as input, then wait a clock cycle for them to stay there. """
#     dut.rst_in.value = 0;
#     dut.x_in.value = x_in;
#     dut.y_in.value = y_in;
#     dut.valid_in.value = 0;
#     dut.tabulate_in.value = 0;
#     await ClockCycles(dut.clk_in,1);


# async def drive_divide_signal_to_cm(dut):
#     """ submit a set of data values as input, then wait a clock cycle for them to stay there. """
#     dut.rst_in.value = 0;
#     dut.x_in.value = 0;
#     dut.y_in.value = 1;
#     dut.valid_in.value = 0;
#     dut.tabulate_in.value = 1;
#     await ClockCycles(dut.clk_in,1);
#     dut.tabulate_in.value = 0;
    
# def cast_base_2(integer):
#     return int(str(integer),2)

# async def wait_for_valid_out(dut,expected_value_x,expected_value_y,max_limit):
#     has_seen_valid_out = False
#     for i in range(max_limit):
#         if (dut.valid_out.value == 1 ):
#             if (has_seen_valid_out):
#                 print("saw valid out twice")
#                 assert False
#             if((cast_base_2(dut.x_out.value) != expected_value_x) or (cast_base_2(dut.y_out.value) != expected_value_y)):
#                 print("incorrect center of mass got" )
#                 print(cast_base_2(dut.x_out.value))
#                 print(cast_base_2(dut.y_out.value))
#                 print("expected")
#                 print(expected_value_x)
#                 print(expected_value_y)
#                 assert False
#             else:
#                 has_seen_valid_out = True
#         await ClockCycles(dut.clk_in,1)
#     if (not has_seen_valid_out):
#         print("never saw valid out")
#         assert False

# async def wait_for_no_valid_out(dut,max_limit):
#     for i in range(max_limit):
#         if (dut.valid_out.value == 1 ):
#             print("saw valid out when wasn't expected")
#             assert False
#         await ClockCycles(dut.clk_in,1)

def get_kernel_used():
    if K_SELECT == 0:
        return [[0,0,0],[0,1,0],[0,0,0]]
    elif K_SELECT == 1:
        return [[1/16,2/16,1/16],[2/16,4/16,2/16],[1/16,2/16,1/16]]
    elif K_SELECT == 2:
        return [[0,-1,0],[-1,5,-1],[0,-1,0]]
    elif K_SELECT == 3:
        return [[-1,-1,-1],[-1,8,-1],[-1,-1,-1]]
    elif K_SELECT == 4:
        return [[-1,0,1],[-2,0,2],[-1,0,1]]
    elif K_SELECT == 5:
        return [[-1,-2,-1],[0,0,0],[1,2,1]]
    else:
        return [[0,1,1],[-1,0,1],[-1,-1,0]]

def compute_pix_out(pixies):
    kernel = get_kernel_used()
    red_out = 0
    green_out = 0
    blue_out = 0
    for i in range(3):
        for j in range(3):
            red_out += kernel[i][j]*(pixies[i][j]//(2**11))
            green_out += kernel[i][j]*((pixies[i][j]//(2**5))  % (2**6))
            blue_out += kernel[i][j]*(pixies[i][j] % (2**5))
    # print(red_out,green_out,blue_out)
    if red_out < 0:
        red_out = 0
    if green_out < 0:
        green_out = 0
    if blue_out < 0:
        blue_out = 0
    return cast_color(int(red_out),int(green_out),int(blue_out))

def cast_color(red,green,blue):
    return ((red %32)*2** 11) + ((green %64)* 2**5) + (blue%32)

def cast_data_input(pix0,pix1,pix2):
    return pix2*2**32 + pix1*2**16 + pix0

async def send_pixel_row(dut,clk_in,data,hcount_in,vcount_in,data_valid_in):
    dut.hcount_in.value = hcount_in
    dut.vcount_in.value = vcount_in
    dut.data_in.value = data
    dut.data_valid_in.value = data_valid_in
    await ClockCycles(clk_in,1)


    
@cocotb.test()
async def  test_kernel(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.data_valid_in.value = 0
    await reset(dut.rst_in,dut.clk_in)
    dut.data_valid_in.value = 1
    pixies_sent = []
    for i in range(500):
        pix0 =cast_color(3*i,5*i,7*i)
        pix1 =cast_color(9*i,11*i,13*i)
        pix2 =cast_color(15*i,17*i,19*i)
        await send_pixel_row(dut,dut.clk_in,cast_data_input(pix0,pix1,pix2),0,0,1)
        pixies_sent.append(([pix0,pix1,pix2]))
        if (i>=(CYCLES_DELAYED+2)):
            assert (dut.data_valid_out.value == 1)
            assert (int(dut.line_out.value) == compute_pix_out(pixies_sent))
            pixies_sent.pop(0)


@cocotb.test()
async def test_produce_popcat(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.data_valid_in.value = 0
    await reset(dut.rst_in,dut.clk_in)
    dut.data_valid_in.value = 1
    im_input = Image.open("/home/yoshicabeza/6.205/lab07/sim/x.png")
    im_input = im_input.convert('RGB')
    im_output = Image.new('RGB',(im_input.size[0]-2,im_input.size[1]-2))
    im_ref = Image.new('RGB',(im_input.size[0]-2,im_input.size[1]-2))
    # example access pixel at coordinate x,y

    for x in range(1,im_input.size[0]-1):
        for y in range(1,im_input.size[1]-1):
            im_output.putpixel((x-1,y-1),(0,0,0))
            im_ref.putpixel((x-1,y-1),(0,0,0))
    im_output.save('output.png','PNG')
    im_ref.save('ref.png','PNG')
    for x in range(1,im_input.size[0]-1):
        print(x)
        for y in range(1,im_input.size[1]-1):
            for  i in [-1,0,1]:
                pix1 = im_input.getpixel( (x+i,y-1) )
                pix1 = cast_color(pix1[0],pix1[1],pix1[2])
                pix2 = im_input.getpixel( (x+i,y) )
                pix2 = cast_color(pix2[0],pix2[1],pix2[2])
                pix3 = im_input.getpixel( (x+i,y+1) )
                pix3 = cast_color(pix3[0],pix3[1],pix3[2])        
                await send_pixel_row(dut,dut.clk_in,cast_data_input(pix1,pix2,pix3),0,0,1)
                if i == 0:
                    blue =pix1% (2**5)
                    green = (pix1 // (2**5)) % (2**6)
                    red = (pix1 // (2**11))
                    im_ref.putpixel((x-1,y-1),(red*8,green*4,blue*8))

            await ClockCycles(dut.clk_in,2)
            blue = dut.line_out.value % (2**5)
            green = (dut.line_out.value // (2**5)) % (2**6)
            red = (dut.line_out.value // (2**11))
            im_output.putpixel((x-1,y-1),(red*8,green*4,blue*8))
    im_output.save('output.png','PNG')
    im_ref.save('ref.png','PNG')
#     dut.data_valid_in.value = 0
#     await reset(dut.rst_in,dut.clk_in)
#     dut.data_valid_in.value = 1
#     pixies_sent = []
#     pix0 =cast_color(0,0,0)
#     pix1 =cast_color(10,10,10)
#     pix2 =cast_color(10,10,10)
#     await send_pixel_row(dut,dut.clk_in,cast_data_input(pix0,pix1,pix2),0,0,1)
#     pixies_sent.append(([pix0,pix1,pix2]))
#     await send_pixel_row(dut,dut.clk_in,cast_data_input(pix0,pix1,pix2),0,0,1)
#     pixies_sent.append(([pix0,pix1,pix2]))
#     await send_pixel_row(dut,dut.clk_in,cast_data_input(pix0,pix1,pix2),0,0,1)
#     pixies_sent.append(([pix0,pix1,pix2]))
#     await ClockCycles(dut.clk_in,2)
    
#     print(compute_pix_out(pixies_sent))
#     print(int(dut.line_out.value))


    # for i in range(500):
    #     pix0 =cast_color(3*i,5*i,7*i)
    #     pix1 =cast_color(9*i,11*i,13*i)
    #     pix2 =cast_color(15*i,17*i,19*i)
    #     await send_pixel_row(dut,dut.clk_in,cast_data_input(pix0,pix1,pix2),0,0,1)
    #     pixies_sent.append(([pix0,pix1,pix2]))
    #     if (i>=(CYCLES_DELAYED+2)):
    #         # print(i)
    #         print(compute_pix_out(pixies_sent))
    #         print(int(dut.line_out.value))
    #         assert (dut.data_valid_out.value == 1)
    #         assert (int(dut.line_out.value) == compute_pix_out(pixies_sent))
    #         pixies_sent.pop(0)

                

K_SELECT = 5
CYCLES_DELAYED = 3
def test_tmds_runner():
    """Run the TMDS runner. Boilerplate code"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "convolution.sv", proj_path / "hdl" / "kernels.sv",
    proj_path / "hdl" / "pipeliner.sv"
    ]
    build_test_args = ["-Wall"]
    parameters = {"K_SELECT": K_SELECT}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="convolution",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ns'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="convolution",
        test_module="test_convolution",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    test_tmds_runner()