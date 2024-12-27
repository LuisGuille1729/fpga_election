Final Report Paper: https://drive.google.com/file/d/143OVT6iuxnWtDhMSbL-dfiJj0nUf41LN/view?usp=sharing

Abstract—This report presents the design of a Paillier cryptosystem 
implemented entirely on an FPGA fabric. Homomorphic
cryptosystems, such as Paillier, are known to provide large
computational overhead. We present advances to overcome some
of these limitations. We utilize a block stream approach to handle
the logic of the large numbers of our system, and we implement
the hardware to exploit optimizations enabled by this approach
to encrypt and decrypt high quantities of votes in a simulated
election. Finally, we evaluate the performance of our system
compared to a software implementation over a general purpose
processor to demonstrate the efficiency of our system.

fpga_e/ – Encryptor system design & simulation files

fpga_d/ – Decryptor system design & simulation files

python_scripts/ – UART transmission and receiving, and
prototypes for Paillier, Montgomery, Optimized Multiplications, Dividers.
