import {Entity, PrimaryGeneratedColumn, Column, BaseEntity} from 'typeorm'

@Entity({name: 'entry'})
export class Entry extends BaseEntity {
  @PrimaryGeneratedColumn()
  id: number | undefined

  @Column()
  entry: string = ''

  @Column()
  timestamp: number = 0
}
