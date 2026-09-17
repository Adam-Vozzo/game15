"""Shared, metre-scaled waterfall shoreline for the world and its emitters."""
import math
from bisect import bisect_right


def lip(x):
    return 4 + 12 * math.sin(x * .017) + 5 * math.sin(x * .039 + .6)


def _curve():
    controls = [(-246, -110), (-213, -98), (-177, -101), (-143, -108),
                (-116, -122), (-89, -139), (-75, -166), (-66, -198),
                (-68, -230), (-80, -266)]
    extended = [tuple(2 * controls[0][k] - controls[1][k] for k in range(2))]
    extended += controls + [tuple(2 * controls[-1][k] - controls[-2][k] for k in range(2))]
    points = []
    for i in range(len(controls) - 1):
        a, b, c, d = extended[i:i + 4]
        for j in range(20):
            t = j / 20
            points.append(tuple(.5 * (2 * b[k] + (-a[k] + c[k]) * t +
                               (2*a[k] - 5*b[k] + 4*c[k] - d[k]) * t*t +
                               (-a[k] + 3*b[k] - 3*c[k] + d[k]) * t*t*t) for k in range(2)))
    return points + [controls[-1]]


UPPER_LIP = _curve()
UPPER_ARC = [0.]
for a, b in zip(UPPER_LIP, UPPER_LIP[1:]):
    UPPER_ARC.append(UPPER_ARC[-1] + math.dist(a, b))
UPPER_BOUNDARY = UPPER_LIP + [(-84, -292), (-279, -292), (-279, -115)]


def upper_sample(distance):
    i = min(len(UPPER_LIP) - 2, max(0, bisect_right(UPPER_ARC, distance) - 1))
    a, b = UPPER_LIP[i:i+2]
    length = UPPER_ARC[i+1] - UPPER_ARC[i]
    t = min(1., max(0., (distance - UPPER_ARC[i]) / length))
    tangent = ((b[0]-a[0])/length, (b[1]-a[1])/length)
    return (a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t), (-tangent[1], tangent[0])


def upper_distance(p):
    result = float('inf')
    for a, b in zip(UPPER_LIP, UPPER_LIP[1:]):
        dx, dz = b[0]-a[0], b[1]-a[1]
        t = min(1., max(0., ((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
        result = min(result, math.hypot(p[0]-a[0]-dx*t, p[1]-a[1]-dz*t))
    return result


def upper_contains(x, z):
    inside = False
    for a, b in zip(UPPER_BOUNDARY, UPPER_BOUNDARY[1:] + UPPER_BOUNDARY[:1]):
        if (a[1] > z) != (b[1] > z) and x < (b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0]:
            inside = not inside
    return inside


def water_level(x, z):
    if upper_contains(x, z):
        return 42
    if -225 <= x <= 225 and -260 <= z <= lip(x):
        return 18
    return -35 if -700 <= x <= 700 and -270 <= z <= 650 else None
