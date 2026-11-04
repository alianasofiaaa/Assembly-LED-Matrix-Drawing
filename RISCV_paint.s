.data

emoji:

.word 0x00FFFF00,0x00FF00FF,0x0000FFFF

.align 2 #memory to remember the original and drawn pixel colors
canvas: .zero 3500


.text


li a0, 0xF0000000     # Base address of the LED matrix

li a1, 35             # LED_MATRIX_0_WIDTH = 35 pixels (140 bytes per row)

li a2, 25             # LED_MATRIX_0_HEIGHT = 25

la a3, emoji


#-----save the initial colors of the LED MATRIX-------
la s7, canvas

li t0, 0 #counts pixels
li t1, 875 #total number of pixels

save_pixels:
    slli t2, t0, 2 #pixel counter * 4
    add t3, a0, t2 #led pixel address
    lw t4, 0(t3) #reads current pixel color
    
    add t5, s7, t2 #auxiliary memory address
    sw t4, 0(t5) #saves pixel color
    
    addi t0, t0, 1
    blt t0, t1, save_pixels

# ----------- CURSOR -----------

# (x, y) = (s1, s2)

li s1, 0                  # s1 = x position
li s2, 0                  # s2 = y position

li s3, 0x00AAAAAA         # s3 = gray cursor
li s4, 0xF0000DB0         # s4 = D_PAD_0_BASE

addi s5, a0, 0            # s5 = current pixel address

lw s6, 0(s5)              # save original pixel color in s6
sw s3, 0(s5)              # draw gray cursor at current pixel address


# ----------- MAIN LOOP -----------

# loop constantly checks for movement from d_pad

# if pressed, 1. if not, 0

# read the D_PAD button states into t0
# check if any direction is pressed

# offset: UP = 0, DOWN = 4, LEFT = 8, RIGHT = 12

loop:
    
    li t6, 0xF0000DAC    # dirección base de los switches
    lw t5, 0(t6)         # leer los switches
    
    #switch 0:black
    andi t0, t5, 1
    bnez t0, black
    
    #start with black
    li s3, 0
    
    #switch 1:red
    andi t0, t5, 2
    beqz t0, green
    li t1, 0x00FF0000
    or s3, s3, t1
    
green:
    #switch 2:green
    andi t0, t5, 4
    beqz t0, blue
    li t1, 0x0000FF00
    or s3, s3, t1
    
blue:
    #switch 3:blue
    andi t0, t5, 8
    beqz t0, gray
    li t1, 0x000000FF
    or s3, s3, t1
    
gray:
    #no color selected
    andi t0, t5, 14
    bnez t0, movement
    li, s3, 0x00AAAAAA
    j movement

black:
    #eraser selected
    li s3, 0
    
movement: 
    #update the color of the current cursor
    sw s3, 0(s5)
    
    lw t0, 0(s4)
    bnez t0, up
    
    lw t0, 4(s4)
    bnez t0, down
    
    lw t0, 8(s4)
    bnez t0, left
    
    lw t0, 12(s4)
    bnez t0,right
    
    j loop
    
# ----------- MOVEMENT -----------

# how the cursor will move. (x, y) = (s1, s2)

# up and left should decrease their coordinates
# down and right should increase their coordinates

# x must stay between 0 and 34
# y must stay between 0 and 24

# if the cursor reaches a border, wait for button release.
# if not, update coordinates and cursor posititon

up:
    beqz s2, wait
    addi s2, s2, -1
    j position

down:
    li t0, 24
    bge s2, t0, wait
    addi s2, s2, 1
    j position

left:
    beqz s1, wait
    addi s1, s1, -1
    j position

right:
    li t0, 34
    bge s1, t0, wait
    addi s1, s1, 1
    j position

# ----------- UPDATE CURSOR -----------

# after moving, it should erase the cursor from its
# previous position. calculates the next position
# the cursor will be at and draws it in that new 
# position

# a0 = matrix base address
# a1 = matrix width
# s1 = x coordinate (columns)
# s2 = y coordinate (rows)
# s3 = cursor color
# s5 = current cursor pixel address
# s6 = original color of current pixel 

position:
    #find previous pixel in canvas memory
    sub t1, s5, a0
    add t1, s7, t1
    
    #check if a color por eraser is selected
    andi t0, t5, 15
    beqz t0, leave_pixel
    
    #store the selected color in the canvas
    sw s3, 0(t1)
    
leave_pixel:
    #restore previous color
    lw t2, 0(t1)
    sw t2, 0(s5)
    
    #calculate next posistion
    mul t1, s2, a1
    add t1, t1, s1
    slli t1, t1, 2
    
    #new pixel address
    add s5, a0, t1
    
    #display cursor at new position
    sw s3, 0(s5)
    
    j wait     # wait until buttons are released
    

# ----------- WAIT FOR BUTTON RELEASE -----------

# wait until all D_PAD buttons are released 
# before letting the cursor move

wait:
    lw t0, 0(s4)            # read up button    
    bnez t0, wait           # if up is pressed, keep waiting
    
    lw t0, 4(s4)            # read down button
    bnez t0, wait           # if down is pressed, keep waiting
    
    lw t0, 8(s4)            # read left button
    bnez t0, wait           # if left is pressed, keep waiting
    
    lw t0, 12(s4)           # read right button
    bnez t0, wait           # if right is pressed, keep waiting
    
    j loop                  # all buttons released. check for new input