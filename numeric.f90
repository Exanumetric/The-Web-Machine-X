program The_Web_Machine_X
    implicit none
    integer :: passed
    integer :: failed
    passed = 0
    failed = 0
    print *, "=============================================="
    print *, "The Web Machine X - v0.0.2"
    print *, "=============================================="
    call test_arithmetic(passed, failed)
    call test_integer_division(passed, failed)
    call test_logic(passed, failed)
    call test_arrays(passed, failed)
    call test_loops(passed, failed)
    call test_strings(passed, failed)
    call test_procedures(passed, failed)
    call test_matrices(passed, failed)
    print *, "----------------------------------------------"
    print *, "Tests passed:", passed
    print *, "Tests failed:", failed
    if (failed == 0) then
        print *, "RESULT: ALL TESTS PASSED"
    else
        print *, "RESULT: SOME TESTS FAILED"
    end if
    print *, "=============================================="
contains
    subroutine check(condition, description, passed_count, failed_count)
        implicit none
        logical, intent(in) :: condition
        character(len=*), intent(in) :: description
        integer, intent(inout) :: passed_count
        integer, intent(inout) :: failed_count
        if (condition) then
            passed_count = passed_count + 1
            print *, "[PASS] ", trim(description)
        else
            failed_count = failed_count + 1
            print *, "[FAIL] ", trim(description)
        end if
    end subroutine check
    subroutine test_arithmetic(passed_count, failed_count)
        implicit none
        integer, intent(inout) :: passed_count
        integer, intent(inout) :: failed_count
        integer :: a, b
        real :: x, y
        a = 24
        b = 6
        x = 2.5
        y = 4.0
        call check(a + b == 30, "integer addition", passed_count, failed_count)
        call check(a - b == 18, "integer subtraction", passed_count, failed_count)
        call check(a * b == 144, "integer multiplication", passed_count, failed_count)
        call check(abs(x * y - 10.0) < 0.0001, "real multiplication", passed_count, failed_count)
        call check(abs(x + y - 6.5) < 0.0001, "real addition", passed_count, failed_count)
    end subroutine test_arithmetic
    subroutine test_integer_division(passed_count, failed_count)
        implicit none
        integer, intent(inout) :: passed_count
        integer, intent(inout) :: failed_count
        integer :: quotient, remainder_value
        quotient = 29 / 5
        remainder_value = mod(29, 5)
        call check(quotient == 5, "integer division", passed_count, failed_count)
        call check(remainder_value == 4, "MOD remainder", passed_count, failed_count)
        call check(modulo(-29, 5) == 1, "MODULO with negative value", passed_count, failed_count)
    end subroutine test_integer_division
    subroutine test_logic(passed_count, failed_count)
        implicit none
        integer, intent(inout) :: passed_count
        integer, intent(inout) :: failed_count
        logical :: first, second
        first = .true.
        second = .false.
        call check(first .and. .not. second, "logical AND and NOT", passed_count, failed_count)
        call check(first .or. second, "logical OR", passed_count, failed_count)
        call check(.not. second, "logical negation", passed_count, failed_count)
        call check(7 > 3 .and. 3 < 9, "combined comparisons", passed_count, failed_count)
    end subroutine test_logic
    subroutine test_arrays(passed_count, failed_count)
        implicit none
        integer, intent(inout) :: passed_count
        integer, intent(inout) :: failed_count
        integer :: values(5)
        integer :: total
        values = [2, 4, 6, 8, 10]
        total = sum(values)
        call check(size(values) == 5, "array size", passed_count, failed_count)
        call check(values(1) == 2, "first array element", passed_count, failed_count)
        call check(values(5) == 10, "last array element", passed_count, failed_count)
        call check(total == 30, "array SUM intrinsic", passed_count, failed_count)
        call check(maxval(values) == 10, "array MAXVAL intrinsic", passed_count, failed_count)
        call check(minval(values) == 2, "array MINVAL intrinsic", passed_count, failed_count)
    end subroutine test_arrays
    subroutine test_loops(passed_count, failed_count)
        implicit none
        integer, intent(inout) :: passed_count
        integer, intent(inout) :: failed_count
        integer :: i
        integer :: total
        integer :: countdown
        total = 0
        do i = 1, 10
            total = total + i
        end do
        countdown = 0
        do i = 5, 1, -1
            countdown = countdown + i
        end do
        call check(total == 55, "DO loop accumulation", passed_count, failed_count)
        call check(countdown == 15, "descending DO loop", passed_count, failed_count)
    end subroutine test_loops
    subroutine test_strings(passed_count, failed_count)
        implicit none
        integer, intent(inout) :: passed_count
        integer, intent(inout) :: failed_count
        character(len=20) :: language
        character(len=40) :: message
        integer :: position
        language = "Fortran"
        message = "Web Machine X"
        position = index(message, "Machine")
        call check(trim(language) == "Fortran", "TRIM intrinsic", passed_count, failed_count)
        call check(len_trim(language) == 7, "LEN_TRIM intrinsic", passed_count, failed_count)
        call check(position == 5, "INDEX intrinsic", passed_count, failed_count)
        call check(trim(language // " Lab") == "Fortran Lab", "string concatenation", passed_count, failed_count)
    end subroutine test_strings
    subroutine test_procedures(passed_count, failed_count)
        implicit none
        integer, intent(inout) :: passed_count
        integer, intent(inout) :: failed_count
        integer :: result_value
        result_value = square(9)
        call check(result_value == 81, "user-defined function", passed_count, failed_count)
        call check(factorial(5) == 120, "recursive factorial function", passed_count, failed_count)
        call check(greatest_common_divisor(48, 18) == 6, "recursive GCD function", passed_count, failed_count)
        call check(square(1) == 1, "square function test 1", passed_count, failed_count)
        call check(square(2) == 4, "square function test 2", passed_count, failed_count)
        call check(square(3) == 9, "square function test 3", passed_count, failed_count)
        call check(square(4) == 16, "square function test 4", passed_count, failed_count)
        call check(square(5) == 25, "square function test 5", passed_count, failed_count)
        call check(square(6) == 36, "square function test 6", passed_count, failed_count)
        call check(square(7) == 49, "square function test 7", passed_count, failed_count)
        call check(square(8) == 64, "square function test 8", passed_count, failed_count)
        call check(square(9) == 81, "square function test 9", passed_count, failed_count)
        call check(square(10) == 100, "square function test 10", passed_count, failed_count)
        call check(square(11) == 121, "square function test 11", passed_count, failed_count)
        call check(square(12) == 144, "square function test 12", passed_count, failed_count)
        call check(square(13) == 169, "square function test 13", passed_count, failed_count)
        call check(square(14) == 196, "square function test 14", passed_count, failed_count)
        call check(square(15) == 225, "square function test 15", passed_count, failed_count)
        call check(square(16) == 256, "square function test 16", passed_count, failed_count)
        call check(square(17) == 289, "square function test 17", passed_count, failed_count)
        call check(square(18) == 324, "square function test 18", passed_count, failed_count)
        call check(square(19) == 361, "square function test 19", passed_count, failed_count)
        call check(square(20) == 400, "square function test 20", passed_count, failed_count)
        call check(square(21) == 441, "square function test 21", passed_count, failed_count)
        call check(square(22) == 484, "square function test 22", passed_count, failed_count)
        call check(square(23) == 529, "square function test 23", passed_count, failed_count)
        call check(square(24) == 576, "square function test 24", passed_count, failed_count)
        call check(square(25) == 625, "square function test 25", passed_count, failed_count)
        call check(square(26) == 676, "square function test 26", passed_count, failed_count)
        call check(square(27) == 729, "square function test 27", passed_count, failed_count)
        call check(square(28) == 784, "square function test 28", passed_count, failed_count)
        call check(square(29) == 841, "square function test 29", passed_count, failed_count)
        call check(square(30) == 900, "square function test 30", passed_count, failed_count)
        call check(square(31) == 961, "square function test 31", passed_count, failed_count)
        call check(square(32) == 1024, "square function test 32", passed_count, failed_count)
        call check(square(33) == 1089, "square function test 33", passed_count, failed_count)
        call check(square(34) == 1156, "square function test 34", passed_count, failed_count)
        call check(square(35) == 1225, "square function test 35", passed_count, failed_count)
        call check(square(36) == 1296, "square function test 36", passed_count, failed_count)
        call check(square(37) == 1369, "square function test 37", passed_count, failed_count)
        call check(square(38) == 1444, "square function test 38", passed_count, failed_count)
        call check(square(39) == 1521, "square function test 39", passed_count, failed_count)
        call check(square(40) == 1600, "square function test 40", passed_count, failed_count)
        call check(square(41) == 1681, "square function test 41", passed_count, failed_count)
        call check(square(42) == 1764, "square function test 42", passed_count, failed_count)
        call check(square(43) == 1849, "square function test 43", passed_count, failed_count)
        call check(square(44) == 1936, "square function test 44", passed_count, failed_count)
        call check(square(45) == 2025, "square function test 45", passed_count, failed_count)
        call check(square(46) == 2116, "square function test 46", passed_count, failed_count)
        call check(square(47) == 2209, "square function test 47", passed_count, failed_count)
        call check(square(48) == 2304, "square function test 48", passed_count, failed_count)
        call check(square(49) == 2401, "square function test 49", passed_count, failed_count)
        call check(square(50) == 2500, "square function test 50", passed_count, failed_count)
        call check(square(51) == 2601, "square function test 51", passed_count, failed_count)
        call check(square(52) == 2704, "square function test 52", passed_count, failed_count)
        call check(square(53) == 2809, "square function test 53", passed_count, failed_count)
        call check(square(54) == 2916, "square function test 54", passed_count, failed_count)
        call check(square(55) == 3025, "square function test 55", passed_count, failed_count)
        call check(square(56) == 3136, "square function test 56", passed_count, failed_count)
        call check(square(57) == 3249, "square function test 57", passed_count, failed_count)
        call check(square(58) == 3364, "square function test 58", passed_count, failed_count)
        call check(square(59) == 3481, "square function test 59", passed_count, failed_count)
        call check(square(60) == 3600, "square function test 60", passed_count, failed_count)
        call check(square(61) == 3721, "square function test 61", passed_count, failed_count)
        call check(square(62) == 3844, "square function test 62", passed_count, failed_count)
        call check(square(63) == 3969, "square function test 63", passed_count, failed_count)
        call check(square(64) == 4096, "square function test 64", passed_count, failed_count)
        call check(square(65) == 4225, "square function test 65", passed_count, failed_count)
        call check(square(66) == 4356, "square function test 66", passed_count, failed_count)
        call check(square(67) == 4489, "square function test 67", passed_count, failed_count)
        call check(square(68) == 4624, "square function test 68", passed_count, failed_count)
        call check(square(69) == 4761, "square function test 69", passed_count, failed_count)
        call check(square(70) == 4900, "square function test 70", passed_count, failed_count)
        call check(square(71) == 5041, "square function test 71", passed_count, failed_count)
        call check(square(72) == 5184, "square function test 72", passed_count, failed_count)
        call check(square(73) == 5329, "square function test 73", passed_count, failed_count)
        call check(square(74) == 5476, "square function test 74", passed_count, failed_count)
        call check(square(75) == 5625, "square function test 75", passed_count, failed_count)
        call check(square(76) == 5776, "square function test 76", passed_count, failed_count)
        call check(square(77) == 5929, "square function test 77", passed_count, failed_count)
        call check(square(78) == 6084, "square function test 78", passed_count, failed_count)
        call check(square(79) == 6241, "square function test 79", passed_count, failed_count)
        call check(square(80) == 6400, "square function test 80", passed_count, failed_count)
        call check(square(81) == 6561, "square function test 81", passed_count, failed_count)
        call check(square(82) == 6724, "square function test 82", passed_count, failed_count)
        call check(square(83) == 6889, "square function test 83", passed_count, failed_count)
        call check(square(84) == 7056, "square function test 84", passed_count, failed_count)
        call check(square(85) == 7225, "square function test 85", passed_count, failed_count)
        call check(square(86) == 7396, "square function test 86", passed_count, failed_count)
        call check(square(87) == 7569, "square function test 87", passed_count, failed_count)
        call check(square(88) == 7744, "square function test 88", passed_count, failed_count)
        call check(square(89) == 7921, "square function test 89", passed_count, failed_count)
        call check(square(90) == 8100, "square function test 90", passed_count, failed_count)
        call check(square(91) == 8281, "square function test 91", passed_count, failed_count)
        call check(square(92) == 8464, "square function test 92", passed_count, failed_count)
        call check(square(93) == 8649, "square function test 93", passed_count, failed_count)
        call check(square(94) == 8836, "square function test 94", passed_count, failed_count)
        call check(square(95) == 9025, "square function test 95", passed_count, failed_count)
        call check(square(96) == 9216, "square function test 96", passed_count, failed_count)
        call check(square(97) == 9409, "square function test 97", passed_count, failed_count)
        call check(square(98) == 9604, "square function test 98", passed_count, failed_count)
        call check(square(99) == 9801, "square function test 99", passed_count, failed_count)
        call check(square(100) == 10000, "square function test 100", passed_count, failed_count)
        call check(square(101) == 10201, "square function test 101", passed_count, failed_count)
        call check(square(102) == 10404, "square function test 102", passed_count, failed_count)
        call check(square(103) == 10609, "square function test 103", passed_count, failed_count)
        call check(square(104) == 10816, "square function test 104", passed_count, failed_count)
        call check(square(105) == 11025, "square function test 105", passed_count, failed_count)
        call check(square(106) == 11236, "square function test 106", passed_count, failed_count)
        call check(square(107) == 11449, "square function test 107", passed_count, failed_count)
        call check(square(108) == 11664, "square function test 108", passed_count, failed_count)
        call check(square(109) == 11881, "square function test 109", passed_count, failed_count)
        call check(square(110) == 12100, "square function test 110", passed_count, failed_count)
        call check(square(111) == 12321, "square function test 111", passed_count, failed_count)
        call check(square(112) == 12544, "square function test 112", passed_count, failed_count)
        call check(square(113) == 12769, "square function test 113", passed_count, failed_count)
        call check(square(114) == 12996, "square function test 114", passed_count, failed_count)
        call check(square(115) == 13225, "square function test 115", passed_count, failed_count)
        call check(square(116) == 13456, "square function test 116", passed_count, failed_count)
        call check(square(117) == 13689, "square function test 117", passed_count, failed_count)
        call check(square(118) == 13924, "square function test 118", passed_count, failed_count)
        call check(square(119) == 14161, "square function test 119", passed_count, failed_count)
        call check(square(120) == 14400, "square function test 120", passed_count, failed_count)
        call check(square(121) == 14641, "square function test 121", passed_count, failed_count)
        call check(square(122) == 14884, "square function test 122", passed_count, failed_count)
        call check(square(123) == 15129, "square function test 123", passed_count, failed_count)
        call check(square(124) == 15376, "square function test 124", passed_count, failed_count)
        call check(square(125) == 15625, "square function test 125", passed_count, failed_count)
        call check(square(126) == 15876, "square function test 126", passed_count, failed_count)
        call check(square(127) == 16129, "square function test 127", passed_count, failed_count)
        call check(square(128) == 16384, "square function test 128", passed_count, failed_count)
        call check(square(129) == 16641, "square function test 129", passed_count, failed_count)
        call check(square(130) == 16900, "square function test 130", passed_count, failed_count)
        call check(square(131) == 17161, "square function test 131", passed_count, failed_count)
        call check(square(132) == 17424, "square function test 132", passed_count, failed_count)
        call check(square(133) == 17689, "square function test 133", passed_count, failed_count)
        call check(square(134) == 17956, "square function test 134", passed_count, failed_count)
        call check(square(135) == 18225, "square function test 135", passed_count, failed_count)
        call check(square(136) == 18496, "square function test 136", passed_count, failed_count)
        call check(square(137) == 18769, "square function test 137", passed_count, failed_count)
        call check(square(138) == 19044, "square function test 138", passed_count, failed_count)
        call check(square(139) == 19321, "square function test 139", passed_count, failed_count)
        call check(square(140) == 19600, "square function test 140", passed_count, failed_count)
        call check(square(141) == 19881, "square function test 141", passed_count, failed_count)
        call check(square(142) == 20164, "square function test 142", passed_count, failed_count)
        call check(square(143) == 20449, "square function test 143", passed_count, failed_count)
        call check(square(144) == 20736, "square function test 144", passed_count, failed_count)
        call check(square(145) == 21025, "square function test 145", passed_count, failed_count)
        call check(square(146) == 21316, "square function test 146", passed_count, failed_count)
        call check(square(147) == 21609, "square function test 147", passed_count, failed_count)
        call check(square(148) == 21904, "square function test 148", passed_count, failed_count)
        call check(square(149) == 22201, "square function test 149", passed_count, failed_count)
        call check(square(150) == 22500, "square function test 150", passed_count, failed_count)
        call check(square(151) == 22801, "square function test 151", passed_count, failed_count)
        call check(square(152) == 23104, "square function test 152", passed_count, failed_count)
        call check(square(153) == 23409, "square function test 153", passed_count, failed_count)
        call check(square(154) == 23716, "square function test 154", passed_count, failed_count)
        call check(square(155) == 24025, "square function test 155", passed_count, failed_count)
        call check(square(156) == 24336, "square function test 156", passed_count, failed_count)
        call check(square(157) == 24649, "square function test 157", passed_count, failed_count)
        call check(square(158) == 24964, "square function test 158", passed_count, failed_count)
        call check(square(159) == 25281, "square function test 159", passed_count, failed_count)
        call check(square(160) == 25600, "square function test 160", passed_count, failed_count)
        call check(square(161) == 25921, "square function test 161", passed_count, failed_count)
        call check(square(162) == 26244, "square function test 162", passed_count, failed_count)
        call check(square(163) == 26569, "square function test 163", passed_count, failed_count)
        call check(square(164) == 26896, "square function test 164", passed_count, failed_count)
        call check(square(165) == 27225, "square function test 165", passed_count, failed_count)
        call check(square(166) == 27556, "square function test 166", passed_count, failed_count)
        call check(square(167) == 27889, "square function test 167", passed_count, failed_count)
        call check(square(168) == 28224, "square function test 168", passed_count, failed_count)
        call check(square(169) == 28561, "square function test 169", passed_count, failed_count)
        call check(square(170) == 28900, "square function test 170", passed_count, failed_count)
        call check(square(171) == 29241, "square function test 171", passed_count, failed_count)
        call check(square(172) == 29584, "square function test 172", passed_count, failed_count)
        call check(square(173) == 29929, "square function test 173", passed_count, failed_count)
        call check(square(174) == 30276, "square function test 174", passed_count, failed_count)
        call check(square(175) == 30625, "square function test 175", passed_count, failed_count)
        call check(square(176) == 30976, "square function test 176", passed_count, failed_count)
        call check(square(177) == 31329, "square function test 177", passed_count, failed_count)
        call check(square(178) == 31684, "square function test 178", passed_count, failed_count)
        call check(square(179) == 32041, "square function test 179", passed_count, failed_count)
        call check(square(180) == 32400, "square function test 180", passed_count, failed_count)
        call check(square(181) == 32761, "square function test 181", passed_count, failed_count)
        call check(square(182) == 33124, "square function test 182", passed_count, failed_count)
        call check(square(183) == 33489, "square function test 183", passed_count, failed_count)
        call check(square(184) == 33856, "square function test 184", passed_count, failed_count)
        call check(square(185) == 34225, "square function test 185", passed_count, failed_count)
        call check(square(186) == 34596, "square function test 186", passed_count, failed_count)
        call check(square(187) == 34969, "square function test 187", passed_count, failed_count)
        call check(square(188) == 35344, "square function test 188", passed_count, failed_count)
        call check(square(189) == 35721, "square function test 189", passed_count, failed_count)
        call check(square(190) == 36100, "square function test 190", passed_count, failed_count)
        call check(square(191) == 36481, "square function test 191", passed_count, failed_count)
        call check(square(192) == 36864, "square function test 192", passed_count, failed_count)
        call check(square(193) == 37249, "square function test 193", passed_count, failed_count)
        call check(square(194) == 37636, "square function test 194", passed_count, failed_count)
        call check(square(195) == 38025, "square function test 195", passed_count, failed_count)
        call check(square(196) == 38416, "square function test 196", passed_count, failed_count)
        call check(square(197) == 38809, "square function test 197", passed_count, failed_count)
        call check(square(198) == 39204, "square function test 198", passed_count, failed_count)
        call check(square(199) == 39601, "square function test 199", passed_count, failed_count)
        call check(square(200) == 40000, "square function test 200", passed_count, failed_count)
        call check(square(201) == 40401, "square function test 201", passed_count, failed_count)
        call check(square(202) == 40804, "square function test 202", passed_count, failed_count)
        call check(square(203) == 41209, "square function test 203", passed_count, failed_count)
        call check(square(204) == 41616, "square function test 204", passed_count, failed_count)
        call check(square(205) == 42025, "square function test 205", passed_count, failed_count)
        call check(square(206) == 42436, "square function test 206", passed_count, failed_count)
        call check(square(207) == 42849, "square function test 207", passed_count, failed_count)
        call check(square(208) == 43264, "square function test 208", passed_count, failed_count)
        call check(square(209) == 43681, "square function test 209", passed_count, failed_count)
        call check(square(210) == 44100, "square function test 210", passed_count, failed_count)
        call check(square(211) == 44521, "square function test 211", passed_count, failed_count)
        call check(square(212) == 44944, "square function test 212", passed_count, failed_count)
        call check(square(213) == 45369, "square function test 213", passed_count, failed_count)
        call check(square(214) == 45796, "square function test 214", passed_count, failed_count)
        call check(square(215) == 46225, "square function test 215", passed_count, failed_count)
        call check(square(216) == 46656, "square function test 216", passed_count, failed_count)
        call check(square(217) == 47089, "square function test 217", passed_count, failed_count)
        call check(square(218) == 47524, "square function test 218", passed_count, failed_count)
        call check(square(219) == 47961, "square function test 219", passed_count, failed_count)
        call check(square(220) == 48400, "square function test 220", passed_count, failed_count)
        call check(square(221) == 48841, "square function test 221", passed_count, failed_count)
        call check(square(222) == 49284, "square function test 222", passed_count, failed_count)
        call check(square(223) == 49729, "square function test 223", passed_count, failed_count)
        call check(square(224) == 50176, "square function test 224", passed_count, failed_count)
        call check(square(225) == 50625, "square function test 225", passed_count, failed_count)
        call check(square(226) == 51076, "square function test 226", passed_count, failed_count)
        call check(square(227) == 51529, "square function test 227", passed_count, failed_count)
        call check(square(228) == 51984, "square function test 228", passed_count, failed_count)
        call check(square(229) == 52441, "square function test 229", passed_count, failed_count)
        call check(square(230) == 52900, "square function test 230", passed_count, failed_count)
        call check(square(231) == 53361, "square function test 231", passed_count, failed_count)
        call check(square(232) == 53824, "square function test 232", passed_count, failed_count)
        call check(square(233) == 54289, "square function test 233", passed_count, failed_count)
        call check(square(234) == 54756, "square function test 234", passed_count, failed_count)
        call check(square(235) == 55225, "square function test 235", passed_count, failed_count)
        call check(square(236) == 55696, "square function test 236", passed_count, failed_count)
        call check(square(237) == 56169, "square function test 237", passed_count, failed_count)
        call check(square(238) == 56644, "square function test 238", passed_count, failed_count)
        call check(square(239) == 57121, "square function test 239", passed_count, failed_count)
        call check(square(240) == 57600, "square function test 240", passed_count, failed_count)
        call check(square(241) == 58081, "square function test 241", passed_count, failed_count)
        call check(square(242) == 58564, "square function test 242", passed_count, failed_count)
        call check(square(243) == 59049, "square function test 243", passed_count, failed_count)
        call check(square(244) == 59536, "square function test 244", passed_count, failed_count)
        call check(square(245) == 60025, "square function test 245", passed_count, failed_count)
        call check(square(246) == 60516, "square function test 246", passed_count, failed_count)
        call check(square(247) == 61009, "square function test 247", passed_count, failed_count)
        call check(square(248) == 61504, "square function test 248", passed_count, failed_count)
        call check(square(249) == 62001, "square function test 249", passed_count, failed_count)
        call check(square(250) == 62500, "square function test 250", passed_count, failed_count)
        call check(square(251) == 63001, "square function test 251", passed_count, failed_count)
        call check(square(252) == 63504, "square function test 252", passed_count, failed_count)
        call check(square(253) == 64009, "square function test 253", passed_count, failed_count)
        call check(square(254) == 64516, "square function test 254", passed_count, failed_count)
        call check(square(255) == 65025, "square function test 255", passed_count, failed_count)
        call check(square(256) == 65536, "square function test 256", passed_count, failed_count)
        call check(square(257) == 66049, "square function test 257", passed_count, failed_count)
        call check(square(258) == 66564, "square function test 258", passed_count, failed_count)
        call check(square(259) == 67081, "square function test 259", passed_count, failed_count)
        call check(square(260) == 67600, "square function test 260", passed_count, failed_count)
        call check(square(261) == 68121, "square function test 261", passed_count, failed_count)
        call check(square(262) == 68644, "square function test 262", passed_count, failed_count)
        call check(square(263) == 69169, "square function test 263", passed_count, failed_count)
        call check(square(264) == 69696, "square function test 264", passed_count, failed_count)
        call check(square(265) == 70225, "square function test 265", passed_count, failed_count)
        call check(square(266) == 70756, "square function test 266", passed_count, failed_count)
        call check(square(267) == 71289, "square function test 267", passed_count, failed_count)
        call check(square(268) == 71824, "square function test 268", passed_count, failed_count)
        call check(square(269) == 72361, "square function test 269", passed_count, failed_count)
        call check(square(270) == 72900, "square function test 270", passed_count, failed_count)
        call check(square(271) == 73441, "square function test 271", passed_count, failed_count)
        call check(square(272) == 73984, "square function test 272", passed_count, failed_count)
        call check(square(273) == 74529, "square function test 273", passed_count, failed_count)
        call check(square(274) == 75076, "square function test 274", passed_count, failed_count)
        call check(square(275) == 75625, "square function test 275", passed_count, failed_count)
        call check(square(276) == 76176, "square function test 276", passed_count, failed_count)
        call check(square(277) == 76729, "square function test 277", passed_count, failed_count)
        call check(square(278) == 77284, "square function test 278", passed_count, failed_count)
        call check(square(279) == 77841, "square function test 279", passed_count, failed_count)
        call check(square(280) == 78400, "square function test 280", passed_count, failed_count)
        call check(square(281) == 78961, "square function test 281", passed_count, failed_count)
        call check(square(282) == 79524, "square function test 282", passed_count, failed_count)
        call check(square(283) == 80089, "square function test 283", passed_count, failed_count)
        call check(square(284) == 80656, "square function test 284", passed_count, failed_count)
        call check(square(285) == 81225, "square function test 285", passed_count, failed_count)
        call check(square(286) == 81796, "square function test 286", passed_count, failed_count)
        call check(square(287) == 82369, "square function test 287", passed_count, failed_count)
        call check(square(288) == 82944, "square function test 288", passed_count, failed_count)
        call check(square(289) == 83521, "square function test 289", passed_count, failed_count)
        call check(square(290) == 84100, "square function test 290", passed_count, failed_count)
        call check(square(291) == 84681, "square function test 291", passed_count, failed_count)
        call check(square(292) == 85264, "square function test 292", passed_count, failed_count)
        call check(square(293) == 85849, "square function test 293", passed_count, failed_count)
        call check(square(294) == 86436, "square function test 294", passed_count, failed_count)
        call check(square(295) == 87025, "square function test 295", passed_count, failed_count)
        call check(square(296) == 87616, "square function test 296", passed_count, failed_count)
        call check(square(297) == 88209, "square function test 297", passed_count, failed_count)
        call check(square(298) == 88804, "square function test 298", passed_count, failed_count)
        call check(square(299) == 89401, "square function test 299", passed_count, failed_count)
        call check(square(300) == 90000, "square function test 300", passed_count, failed_count)
        call check(square(301) == 90601, "square function test 301", passed_count, failed_count)
        call check(square(302) == 91204, "square function test 302", passed_count, failed_count)
        call check(square(303) == 91809, "square function test 303", passed_count, failed_count)
        call check(square(304) == 92416, "square function test 304", passed_count, failed_count)
        call check(square(305) == 93025, "square function test 305", passed_count, failed_count)
        call check(square(306) == 93636, "square function test 306", passed_count, failed_count)
        call check(square(307) == 94249, "square function test 307", passed_count, failed_count)
        call check(square(308) == 94864, "square function test 308", passed_count, failed_count)
        call check(square(309) == 95481, "square function test 309", passed_count, failed_count)
        call check(square(310) == 96100, "square function test 310", passed_count, failed_count)
        call check(square(311) == 96721, "square function test 311", passed_count, failed_count)
    end subroutine test_procedures
    subroutine test_matrices(passed_count, failed_count)
        implicit none
        integer, intent(inout) :: passed_count
        integer, intent(inout) :: failed_count
        integer :: matrix(2, 2)
        integer :: transposed(2, 2)
        matrix = reshape([1, 2, 3, 4], [2, 2])
        transposed = transpose(matrix)
        call check(sum(matrix) == 10, "matrix element sum", passed_count, failed_count)
        call check(matrix(1, 1) == 1, "matrix first element", passed_count, failed_count)
        call check(transposed(1, 2) == matrix(2, 1), "matrix transpose", passed_count, failed_count)
    end subroutine test_matrices
    integer function square(number) result(answer)
        implicit none
        integer, intent(in) :: number
        answer = number * number
    end function square
    recursive integer function factorial(number) result(answer)
        implicit none
        integer, intent(in) :: number
        if (number <= 1) then
            answer = 1
        else
            answer = number * factorial(number - 1)
        end if
    end function factorial
    recursive integer function greatest_common_divisor(a, b) result(answer)
        implicit none
        integer, intent(in) :: a
        integer, intent(in) :: b
        if (b == 0) then
            answer = abs(a)
        else
            answer = greatest_common_divisor(b, mod(a, b))
        end if
    end function greatest_common_divisor
end program The_Web_Machine_X
