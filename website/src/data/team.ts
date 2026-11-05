// The people shown on /team, in card order. Photos live in public/team/.

export interface Member {
  name: string
  role: string
  photo: string
}

export const team: Member[] = [
  { name: 'Kim Andrie Ogdol', role: 'Project Manager', photo: '/team/kim.webp' },
  { name: 'Rozencrantz Oñada', role: 'Hipster', photo: '/team/rozencrantz.webp' },
  { name: 'Lurinylle Clark Ardiente', role: 'Hacker', photo: '/team/lurinylle.webp' },
  { name: 'Erickson Tiu', role: 'Hacker', photo: '/team/erickson.webp' },
]
